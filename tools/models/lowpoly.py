import sys, os, trimesh, pymeshlab
from PIL import Image
W, name, height, target = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
d=f'{W}/work_{name}'; os.makedirs(d, exist_ok=True)
s=trimesh.load(f'{W}/src/{name}.glb'); g=list(s.geometry.values())[0]
print(name, 'src tris', len(g.faces), 'tex', g.visual.material.baseColorTexture.size)
g.apply_translation([0,-g.bounds[0][1],0]); g.apply_scale(height/g.extents[1])
g.visual.material.baseColorTexture.convert('RGB').save(f'{d}/tex.png')
g.export(f'{d}/in.obj')
ms=pymeshlab.MeshSet(); ms.load_new_mesh(f'{d}/in.obj'); ms.meshing_merge_close_vertices()
for t in (8000,4000,target):
    if ms.current_mesh().face_number()>t:
        ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=t, preserveboundary=False, preservenormal=True, optimalplacement=True, extratcoordw=1.0, qualitythr=0.5)
try: ms.meshing_re_orient_faces_coherently()
except Exception as e: print("no reorient")
ms.save_current_mesh(f'{d}/lp.obj')
m=trimesh.load(f'{d}/lp.obj', force='mesh')
tex=Image.open(f'{d}/tex.png').resize((128,128), Image.BOX); tex.save(f'{W}/web/{name}_128.png')
m.visual=trimesh.visual.TextureVisuals(uv=m.visual.uv, material=trimesh.visual.material.PBRMaterial(baseColorTexture=tex, metallicFactor=0, roughnessFactor=1))
m.export(f'{W}/{name}_lowpoly.glb'); os.system(f'cp {d}/lp.obj {W}/web/{name}.obj')
print(name, 'lp tris', len(m.faces), 'h', round(m.extents[1],2))
