"""Зеркальная копия анимации (левая рука вместо правой и наоборот).
blender -b -P mirror_anim.py -- <in.glb> <out.glb> <новое имя>
Берёт готовый GLB из export_anims.py, для каждого кадра вставляет позу, отражённую слева направо
(как Pose → Paste Flipped), и сохраняет в том же виде (Root, anim_skin)."""
import bpy, sys, os
from mathutils import Matrix
SRC, DST, NAME = sys.argv[sys.argv.index('--') + 1:]
P = 'mixamorig:'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
arm = [o for o in sc.objects if o.type == 'ARMATURE'][0]
dummy = [o for o in sc.objects if o.type == 'MESH'][0]
src = arm.animation_data.action
f0, f1 = map(int, src.frame_range)
# Blender узнаёт пары по именам Left*/Right* только в начале имени — временно снимаем префикс
for b in arm.data.bones:
    if b.name.startswith(P):
        b.name = b.name[len(P):]
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.select_all(action='SELECT')
dst = bpy.data.actions.new(NAME)
for fr in range(f0, f1 + 1):
    arm.animation_data.action = src
    sc.frame_set(fr)
    bpy.ops.pose.copy()
    arm.animation_data.action = dst
    bpy.ops.pose.paste(flipped=True)
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.keyframe_insert('rotation_quaternion', frame=fr, group=pb.name)
        if pb.name in ('Hips', 'Root'):
            pb.keyframe_insert('location', frame=fr, group=pb.name)
bpy.ops.object.mode_set(mode='OBJECT')
arm.animation_data.action = dst
bpy.data.actions.remove(src)
for b in arm.data.bones:
    if b.name != 'Root':
        b.name = P + b.name
for vg in dummy.vertex_groups:
    pass  # группы переименовались вместе с костями
dst.use_fake_user = True
for o in sc.objects:
    o.select_set(o in (arm, dummy))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_materials='NONE',
                          export_yup=True, export_def_bones=False, export_force_sampling=True,
                          export_optimize_animation_size=True, export_reset_pose_bones=True)
print('MIRRORED', NAME, f1 - f0 + 1, os.path.getsize(DST))
