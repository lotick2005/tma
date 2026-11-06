"""Общие шаги для экспорта моделей и анимаций Mixamo -> GLB."""
import bpy
import numpy as np
from mathutils import Matrix, Vector

P = 'mixamorig:'
ROOT = 'Root'


def import_fbx(path):
    bpy.ops.import_scene.fbx(filepath=path, global_scale=100.0)
    arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    return arm, meshes


def select_only(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def apply_transforms(arm, meshes):
    """Mixamo приходит с поворотом 90° по X на объекте: запекаем его, чтобы всё было в мировых осях."""
    for m in meshes:
        select_only([m])
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    select_only([arm] + meshes, arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for m in meshes:
        m.parent = arm
        m.matrix_parent_inverse = Matrix()
    arm.name = 'Armature'
    arm.data.name = 'Armature'


def add_root(arm):
    """Кость Root в начале координат над Hips — для root motion в Godot (SkeletonProfileHumanoid: Root)."""
    select_only([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    ebs = arm.data.edit_bones
    if ROOT not in ebs:
        r = ebs.new(ROOT)
        r.head = (0, 0, 0)
        r.tail = (0, 0, 0.1)  # вверх, крен 0: в glTF у Root единичный поворот
        r.roll = 0
        h = ebs[P + 'Hips']
        h.use_connect = False
        h.parent = r
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.data.bones[ROOT].use_deform = False


def hips_world(arm):
    return arm.matrix_world @ arm.pose.bones[P + 'Hips'].head
