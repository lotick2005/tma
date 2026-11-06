"""Сверка: суставы в GLB совпадают с исходным FBX (относительно таза) на всех кадрах.
blender -b -P verify_glb.py -- <root_dir> <anims.json> <glb_dir> <out.json>"""
import bpy, sys, os, json
import numpy as np

ROOT_DIR, LIST, GLB, OUT = sys.argv[sys.argv.index('--') + 1:]
P = 'mixamorig:'
res = {}


def joints(arm, frames):
    sc = bpy.context.scene
    names = [b.name for b in arm.data.bones if b.name.startswith(P)]
    out = []
    for fr in frames:
        sc.frame_set(fr)
        h = np.array(arm.matrix_world @ arm.pose.bones[P + 'Hips'].head)
        out.append([np.array(arm.matrix_world @ arm.pose.bones[n].head) - h for n in names] + [h * [0, 0, 1]])
    return np.array(out)


for d, f, name, mode, note in json.load(open(LIST)):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT_DIR, d, f), global_scale=100.0)
    arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
    f0, f1 = map(int, arm.animation_data.action.frame_range)
    frames = list(range(f0, f1 + 1, 3))[:40] if mode != 'pose' else [f0]
    a = joints(arm, frames)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB, name + '.glb'))
    arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
    act = arm.animation_data.action
    g0, g1 = act.frame_range
    off = int(round(g0)) - f0
    frames_g = [fr + off for fr in frames if fr + off <= g1 + 0.01]
    b = joints(arm, frames_g)
    n = min(len(a), len(b))
    err = float(np.abs(a[:n] - b[:n]).max())
    res[name] = dict(err_m=round(err, 4), glb_range=[g0, g1], fbx_range=[f0, f1], action=act.name)
    print('VERIFY', name, res[name])
json.dump(res, open(OUT, 'w'), indent=1, ensure_ascii=False)
