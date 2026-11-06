"""Анимации Mixamo (FBX) -> отдельные GLB без кожи.
blender -b -P export_anims.py -- <root_dir> <anims.json> <out_dir> <manifest.json>
loop  — на месте: убираем горизонтальный дрейф таза, повтор последнего кадра выкидываем;
once  — горизонтальное перемещение таза переносим в кость Root (root motion);
pose  — один кадр."""
import bpy, sys, os, json, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT_DIR, LIST, OUT, MANIFEST = sys.argv[sys.argv.index('--') + 1:]
os.makedirs(OUT, exist_ok=True)
FPS = 30
entries = json.load(open(LIST))
only = os.environ.get('ONLY')
manifest = []

for d, f, name, mode, note in entries:
    if only and name not in only.split(','):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, meshes = import_fbx(os.path.join(ROOT_DIR, d, f))
    sc = bpy.context.scene
    sc.render.fps = FPS
    act = arm.animation_data.action
    f0, f1 = map(int, act.frame_range)
    for a in list(bpy.data.actions):
        if a != act:
            bpy.data.actions.remove(a)

    def sample():
        out = []
        for fr in range(f0, f1 + 1):
            sc.frame_set(fr)
            out.append(np.array(hips_world(arm)))
        return np.array(out)

    before = sample()
    for m in meshes:
        bpy.data.objects.remove(m, do_unlink=True)
    apply_transforms(arm, [])
    add_root(arm)
    after = sample()
    assert np.abs(before - after).max() < 1e-4, (name, 'поворот сломал анимацию')

    hb = arm.pose.bones[P + 'Hips']
    rb = arm.pose.bones[ROOT]
    # совпадает ли последний кадр с первым (Mixamo дублирует кадр в циклах)
    def pose_vec(fr):
        sc.frame_set(fr)
        v = []
        for pb in arm.pose.bones:
            q = pb.matrix_basis.to_quaternion()
            v.extend(q if q.w >= 0 else -q)
        return np.array(v)
    seam = float(np.abs(pose_vec(f0) - pose_vec(f1)).max())
    p = after
    info = dict(name=name, file=f'{d}/{f}', mode=mode, note=note)

    if mode == 'loop':
        span = f1 - f0
        drift = p[-1] - p[0]
        drift[2] = 0
        mats = []
        for i, fr in enumerate(range(f0, f1 + 1)):
            sc.frame_set(fr)
            m = hb.matrix.copy()
            m.translation -= Vector(drift * (i / span))
            mats.append(m)
        for i, fr in enumerate(range(f0, f1 + 1)):
            sc.frame_set(fr)
            hb.matrix = mats[i]
            hb.keyframe_insert('location', frame=fr, group=hb.name)
        dup = seam < 0.01
        last = f1 - 1 if dup else f1
        if dup:
            for fc in act.fcurves:
                for k in [k for k in fc.keyframe_points if abs(k.co.x - f1) < 0.5]:
                    fc.keyframe_points.remove(k)
        info.update(frames=last - f0 + 1, seconds=round((last - f0 + 1) / FPS, 3),
                    speed_mps=round(float(np.linalg.norm(drift[:2])) / (span / FPS), 2),
                    seam=round(seam, 3), dup_last_removed=dup)
        dirv = drift[:2] / (np.linalg.norm(drift[:2]) + 1e-9)
        # Blender -Y = вперёд персонажа (+Z в glTF / Godot)
        info['direction'] = ('вперёд' if dirv[1] < -0.7 else 'назад' if dirv[1] > 0.7 else
                             'влево' if dirv[0] > 0.7 else 'вправо' if dirv[0] < -0.7 else 'на месте') \
            if np.linalg.norm(drift[:2]) > 0.05 else 'на месте'
    elif mode == 'once':
        mats = []
        for fr in range(f0, f1 + 1):
            sc.frame_set(fr)
            mats.append(hb.matrix.copy())
        for i, fr in enumerate(range(f0, f1 + 1)):
            r = p[i] - p[0]
            # у Root локальные оси: X = мир X, Y = мир Z (вверх), Z = мир -Y
            rb.location = (float(r[0]), 0.0, float(-r[1]))
            rb.keyframe_insert('location', frame=fr, group=ROOT)
        for i, fr in enumerate(range(f0, f1 + 1)):
            sc.frame_set(fr)
            hb.matrix = mats[i]
            hb.keyframe_insert('location', frame=fr, group=hb.name)
        r = p[-1] - p[0]
        info.update(frames=f1 - f0 + 1, seconds=round((f1 - f0 + 1) / FPS, 3),
                    root_motion_m=dict(forward=round(float(-r[1]), 2), right=round(float(-r[0]), 2)))
    elif mode == 'pose':
        for fc in act.fcurves:
            for k in [k for k in fc.keyframe_points if k.co.x > f0 + 0.5]:
                fc.keyframe_points.remove(k)
        info.update(frames=1, seconds=0)

    info['hips_m'] = dict(start=round(float(p[0][2]), 2), end=round(float(p[-1][2]), 2),
                          min=round(float(p[:, 2].min()), 2))
    # проверка: итоговое положение таза в мире не изменилось (для once) / дрейф убран (для loop)
    check = []
    for i, fr in enumerate(range(f0, f0 + info['frames'])):
        sc.frame_set(fr)
        check.append(np.array(hips_world(arm)))
    check = np.array(check)
    if mode == 'once':
        info['check_err'] = round(float(np.abs(check - p[:len(check)]).max()), 5)
    elif mode == 'loop':
        info['check_xy_range'] = round(float(np.ptp(check[:, :2], axis=0).max()), 3)

    act.name = name
    act.use_fake_user = True
    # glTF без кожи — это просто узлы, Godot не соберёт из них Skeleton3D. Поэтому — крошечный
    # треугольник (1 мм) на тазу: файл получает skin со всеми костями, а меш можно не импортировать.
    me = bpy.data.meshes.new('anim_skin')
    me.from_pydata([(0, 0, 0.9), (0.001, 0, 0.9), (0, 0, 0.901)], [], [(0, 1, 2)])
    dummy = bpy.data.objects.new('anim_skin', me)
    sc.collection.objects.link(dummy)
    dummy.parent = arm
    vg = dummy.vertex_groups.new(name=P + 'Hips')
    vg.add([0, 1, 2], 1.0, 'REPLACE')
    for b in arm.data.bones:
        if b.name != P + 'Hips':
            dummy.vertex_groups.new(name=b.name)
    dm = dummy.modifiers.new('Armature', 'ARMATURE')
    dm.object = arm
    select_only([arm, dummy], arm)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + '.glb'), export_format='GLB',
                              use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_skins=True, export_materials='NONE',
                              export_yup=True, export_def_bones=False, export_force_sampling=True,
                              export_optimize_animation_size=True, export_reset_pose_bones=True)
    info['bytes'] = os.path.getsize(os.path.join(OUT, name + '.glb'))
    manifest.append(info)
    print('ANIM', json.dumps(info, ensure_ascii=False))

old = json.load(open(MANIFEST)) if (only and os.path.exists(MANIFEST)) else []
keep = {m['name']: m for m in old}
for m in manifest:
    keep[m['name']] = m
order = [e[2] for e in entries]
json.dump([keep[n] for n in order if n in keep], open(MANIFEST, 'w'), ensure_ascii=False, indent=1)
