"""Персонаж со скелетом -> GLB для Godot.
blender -b -P export_model.py -- <src.fbx|src.blend> <out.glb> <name> <work_dir>
Позу и анимацию сбрасываем, добавляем Root, текстуру ужимаем до 128x128 (nearest)."""
import bpy, sys, os, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

SRC, OUT, NAME, WORK = sys.argv[sys.argv.index('--') + 1:]
os.makedirs(WORK, exist_ok=True)

if SRC.endswith('.blend'):
    bpy.ops.wm.open_mainfile(filepath=SRC)
    arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, meshes = import_fbx(SRC)

if arm.animation_data:
    arm.animation_data_clear()
for pb in arm.pose.bones:
    pb.matrix_basis = Matrix()
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
bpy.context.view_layer.update()

rest_before = np.array([list(v) for m in meshes for v in
                        [m.matrix_world @ x.co for x in m.data.vertices]])
apply_transforms(arm, meshes)
add_root(arm)
rest_after = np.array([list(v) for m in meshes for v in
                       [m.matrix_world @ x.co for x in m.data.vertices]])
assert np.abs(rest_before - rest_after).max() < 1e-4, 'вершины сдвинулись'

# одна поверхность, один материал, текстура 128 nearest
assert len(meshes) == 1, [m.name for m in meshes]
body = meshes[0]
body.name = NAME
body.data.name = NAME
src_img = None
for mat in body.data.materials:
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image:
                src_img = n.image
assert src_img is not None, 'нет текстуры'
w, h = src_img.size
k = w // 128
assert w == h and w % 128 == 0, src_img.size
px = np.array(src_img.pixels[:], dtype=np.float32).reshape(h, w, 4)
small = px.reshape(128, k, 128, k, 4).mean(axis=(1, 3))  # BOX: среднее по блокам k x k
small[..., 3] = 1.0
img = bpy.data.images.new(NAME, 128, 128, alpha=False)
img.pixels[:] = small.ravel()
img.filepath_raw = os.path.join(WORK, NAME + '.png')
img.file_format = 'PNG'
img.save()

mat = bpy.data.materials.new(NAME)
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes['Principled BSDF']
bsdf.inputs['Roughness'].default_value = 1.0
bsdf.inputs['Metallic'].default_value = 0.0
tex = nt.nodes.new('ShaderNodeTexImage')
tex.image = img
tex.interpolation = 'Closest'
nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
body.data.materials.clear()
body.data.materials.append(mat)

# веса: не больше 4 костей на вершину, нормировка
select_only([body])
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
mods = [m for m in body.modifiers if m.type == 'ARMATURE']
assert mods and mods[0].object == arm

tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
select_only([arm, body], arm)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                          export_animations=False, export_skins=True, export_yup=True,
                          export_apply=False, export_materials='EXPORT', export_image_format='AUTO',
                          export_def_bones=False)
info = dict(name=NAME, tris=tris, verts=len(body.data.vertices), bones=len(arm.data.bones),
            height=round(float(rest_after[:, 2].max() - rest_after[:, 2].min()), 3),
            hips_height=round(float((arm.matrix_world @ arm.data.bones[P + 'Hips'].head_local).z), 3))
json.dump(info, open(os.path.join(WORK, NAME + '.json'), 'w'))
print('MODEL', info)
