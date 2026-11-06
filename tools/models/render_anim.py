"""Кадры анимации на персонаже: blender -b -P render_anim.py -- <model.blend|model.glb|skin.fbx> <anim.fbx|anim.glb|-> <out_prefix> <n_frames> [view]
view: 34 (три четверти спереди), side, front."""
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
MODEL, ANIM, OUT, N = args[:4]
VIEW = args[4] if len(args) > 4 else '34'
N = int(N)


def load(path):
    if path.endswith('.blend'):
        bpy.ops.wm.open_mainfile(filepath=path)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        imp(path)


def imp(path):
    if path.endswith('.fbx'):
        bpy.ops.import_scene.fbx(filepath=path, global_scale=100.0)
    else:
        bpy.ops.import_scene.gltf(filepath=path)


load(MODEL)
arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if ANIM != '-':
    before = set(bpy.data.objects)
    acts_before = set(bpy.data.actions)
    imp(ANIM)
    new_objs = set(bpy.data.objects) - before
    act = [a for a in bpy.data.actions if a not in acts_before][0]
    for o in new_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    arm.animation_data_create()
    arm.animation_data.action = act
else:
    act = arm.animation_data.action if arm.animation_data else None

sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x, sc.render.resolution_y = int(os.environ.get("RW", 180)), int(os.environ.get("RH", 270))
sc.render.film_transparent = False
sc.world = sc.world or bpy.data.worlds.new('w')
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.6
ang = {'34': -35, 'side': -90, 'front': 0, 'back': 180}[VIEW]
a = math.radians(ang)
target = Vector((0, 0, 0.9))
d = Vector((math.sin(a), -math.cos(a), 0.0)) * 6
cam.location = target + d
cam.rotation_euler = (math.radians(90), 0, a)

f0, f1 = (map(int, act.frame_range) if act else (1, 1))
frames = [round(f0 + (f1 - f0) * i / max(1, N - 1)) for i in range(N)]
for i, fr in enumerate(frames):
    sc.frame_set(fr)
    # камера следит за тазом по горизонтали
    hips = arm.matrix_world @ arm.pose.bones['mixamorig:Hips'].head
    cam.location = Vector((hips.x, hips.y, 0.9)) + d
    sc.render.filepath = f'{OUT}_{i:02d}.png'
    bpy.ops.render.render(write_still=True)
print('FRAMES', frames)
