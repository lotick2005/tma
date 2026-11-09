import bpy, sys, math
from mathutils import Vector
glb, out = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
for m in ms:
    for mat in m.data.materials:
        for n in mat.node_tree.nodes:
            if n.type=='TEX_IMAGE': n.interpolation='Closest'
pts=[m.matrix_world@v.co for m in ms for v in m.data.vertices]
lo=Vector([min(p[i] for p in pts) for i in range(3)]); hi=Vector([max(p[i] for p in pts) for i in range(3)])
c=(lo+hi)/2; size=max(hi-lo)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
sc.render.resolution_x=sc.render.resolution_y=360
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=size*1.15; cam.data.clip_start=0.001
for i,(ang,el) in enumerate([(0,0),(-40,20),(180,0)]):
    a=math.radians(ang); e=math.radians(el)
    d=Vector((math.sin(a)*math.cos(e), -math.cos(a)*math.cos(e), math.sin(e)))*size*4
    cam.location=c+d; cam.rotation_euler=(math.radians(90)-e,0,a)
    sc.render.filepath=f'{out}_{i}.png'; bpy.ops.render.render(write_still=True)
