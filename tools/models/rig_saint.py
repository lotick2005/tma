"""Скелет героя (Mixamo) -> на модель святого: подгонка суставов, веса через воксельный прокси.
blender -b -P rig_saint.py -- <hero_skin.fbx> <saint.obj> <out.blend> <report.json>
"""
import bpy, bmesh, sys, json, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

HERO_FBX, SAINT_OBJ, OUT_BLEND, REPORT = sys.argv[sys.argv.index('--') + 1:]
P = 'mixamorig:'

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=HERO_FBX, global_scale=100.0)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
hero = [o for o in bpy.data.objects if o.type == 'MESH'][0]
arm.animation_data_clear()
for pb in arm.pose.bones:
    pb.matrix_basis = Matrix()
bpy.context.view_layer.update()
hv = np.array([hero.matrix_world @ v.co for v in hero.data.vertices])
bpy.data.objects.remove(hero, do_unlink=True)

bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
arm.name = 'Armature'

bpy.ops.wm.obj_import(filepath=SAINT_OBJ)
saint = [o for o in bpy.data.objects if o.type == 'MESH'][0]
sv = np.array([saint.matrix_world @ v.co for v in saint.data.vertices])

joints = {b.name[len(P):]: np.array(b.head_local) for b in arm.data.bones}
Hh, Ht = hv[:, 2].max(), sv[:, 2].max()
s = Ht / Hh
new = {k: np.array([v[0], v[1], v[2] * s]) for k, v in joints.items()}
rep = {'joints': {k: [round(float(x), 4) for x in v] for k, v in new.items()} if False else {}, 'scale_z': round(float(s), 4), 'height': round(float(Ht), 3)}


def centroid(V, mask):
    return V[mask].mean(0)


# голова: сдвиг вперёд/назад по центру масс головы
ch = centroid(hv, hv[:, 2] > 0.86 * Hh)
ct = centroid(sv, sv[:, 2] > 0.86 * Ht)
dh = ct - ch * np.array([1, 1, s])
dh[2] = 0
for k, f in [('Neck', 0.5), ('Head', 1.0), ('HeadTop_End', 1.0)]:
    new[k] = new[k] + dh * f
rep['head_shift'] = [round(float(x), 3) for x in dh]


def sim_map(a0, b0, a1, b1):
    """Подобие (поворот+масштаб), переводящее отрезок a0->b0 в a1->b1."""
    v0, v1 = Vector(b0 - a0), Vector(b1 - a1)
    q = v0.rotation_difference(v1)
    k = v1.length / v0.length
    return lambda p: a1 + np.array(q @ (Vector(p - a0) * k))


for side, sgn in (('Left', 1), ('Right', -1)):
    # кисть: центр вершин с края по x (руки в A-позе — самое крайнее)
    def hand_c(V):
        x = V[:, 0] * sgn
        return centroid(V, x > x.max() - 0.09)
    off = joints[side + 'Hand'] - hand_c(hv)
    wrist = hand_c(sv) + off * np.array([1, 1, s])
    sh0, wr0 = joints[side + 'Arm'], joints[side + 'Hand']
    sh1 = new[side + 'Arm']
    f = sim_map(sh0, wr0, sh1, wrist)
    for k in ('ForeArm', 'Hand', 'HandIndex1', 'HandIndex2', 'HandIndex3', 'HandIndex4'):
        new[side + k] = f(joints[side + k])
    rep[side + '_wrist'] = [round(float(x), 3) for x in wrist]

    # стопа: центр нижних вершин своей стороны
    def foot_c(V, H):
        m = (V[:, 2] < 0.07 * H) & (V[:, 0] * sgn > 0.03)
        return centroid(V, m)
    df = foot_c(sv, Ht) - foot_c(hv, Hh) * np.array([1, 1, s])
    df[2] = 0
    for k, w in (('Leg', 0.5), ('Foot', 1.0), ('ToeBase', 1.0), ('Toe_End', 1.0)):
        new[side + k] = new[side + k] + df * w
    rep[side + '_foot_shift'] = [round(float(x), 3) for x in df]

# двигаем кости, не меняя их ориентацию (тогда повороты из анимаций героя подходят как есть)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
ebs = arm.data.edit_bones
for eb in ebs:
    eb.use_connect = False
for eb in ebs:
    k = eb.name[len(P):]
    m = eb.matrix.copy()
    L = eb.length
    m.translation = Vector(new[k])
    eb.matrix = m
    eb.length = L * s
bpy.ops.object.mode_set(mode='OBJECT')

# прокси: та же сетка, но со слитыми по швам UV вершинами (иначе это россыпь островов и «тепловые» веса не считаются)
proxy = saint.copy()
proxy.data = saint.data.copy()
bpy.context.collection.objects.link(proxy)
proxy.name = 'proxy'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = proxy
proxy.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.0005)
bpy.ops.object.mode_set(mode='OBJECT')
rep['proxy_verts'] = len(proxy.data.vertices)

# «тепловые» веса срываются на мелких сетках — считаем в масштабе x10
def scale_all(objs, k):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.scale = (k, k, k)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

scale_all([arm, proxy], 10.0)
bpy.ops.object.select_all(action='DESELECT')
proxy.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
proxy.parent = None
proxy.modifiers.clear()
scale_all([arm, proxy], 0.1)

# сколько вершин прокси осталось без весов
pw = np.zeros(len(proxy.data.vertices))
for v in proxy.data.vertices:
    pw[v.index] = sum(g.weight for g in v.groups)
rep['proxy_unweighted'] = int((pw < 1e-4).sum())

# перенос на настоящую модель
for vg in list(saint.vertex_groups):
    saint.vertex_groups.remove(vg)
for b in arm.data.bones:
    saint.vertex_groups.new(name=b.name)
dt = saint.modifiers.new('dt', 'DATA_TRANSFER')
dt.object = proxy
dt.use_vert_data = True
dt.data_types_verts = {'VGROUP_WEIGHTS'}
dt.vert_mapping = 'NEAREST'
dt.layers_vgroup_select_src = 'ALL'
dt.layers_vgroup_select_dst = 'NAME'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = saint
saint.select_set(True)
bpy.ops.object.modifier_apply(modifier='dt')
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_clean(group_select_mode='ALL', limit=0.02)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)

sw = np.array([sum(g.weight for g in v.groups) for v in saint.data.vertices])
rep['saint_unweighted'] = int((sw < 1e-4).sum())

saint.parent = arm
am = saint.modifiers.new('Armature', 'ARMATURE')
am.object = arm
bpy.data.objects.remove(proxy, do_unlink=True)
saint.name = 'body'
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
rep['joints'] = {k: [round(float(x), 4) for x in v] for k, v in new.items()}
np.save(REPORT.replace('.json', '_v.npy'), sv)
json.dump(rep, open(REPORT, 'w'), indent=1)
print('REPORT', rep)
