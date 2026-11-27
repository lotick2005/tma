# Упростить геометрию без учёта UV, развернуть заново (xatlas) и запечь цвет с исходника в 128×128.
import sys, numpy as np, trimesh, pymeshlab
from PIL import Image
W, name, longest, target = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
s=trimesh.load(f'{W}/src/{name}.glb'); hi=list(s.geometry.values())[0]
c=hi.bounds.mean(axis=0); hi.apply_translation([-c[0],-hi.bounds[0][1],-c[2]]); hi.apply_scale(longest/max(hi.extents))
src_tex=np.asarray(hi.visual.material.baseColorTexture.convert('RGB')); TH,TW=src_tex.shape[:2]
ms=pymeshlab.MeshSet(); ms.add_mesh(pymeshlab.Mesh(hi.vertices, hi.faces)); ms.meshing_merge_close_vertices()
for t in (60000,15000,4000,target):
    if ms.current_mesh().face_number()>t:
        ms.meshing_decimation_quadric_edge_collapse(targetfacenum=t, preservenormal=True, optimalplacement=True, qualitythr=0.3, planarquadric=True)
lm=ms.current_mesh(); lo=trimesh.Trimesh(lm.vertex_matrix(), lm.face_matrix(), process=False)
lo=lo.unwrap()   # xatlas
uv=lo.visual.uv; N=128
img=np.zeros((N,N,3),np.uint8); filled=np.zeros((N,N),bool)
# для каждого текселя: найти треугольник в UV, точка в 3D, ближайшая точка исходника, её UV, цвет
from trimesh.triangles import points_to_barycentric
F=lo.faces; tuv=uv[F]
pts=[];pix=[]
for fi,(a,b,cc) in enumerate(tuv):
    lo_=np.floor(np.minimum(np.minimum(a,b),cc)*N).astype(int); hi_=np.ceil(np.maximum(np.maximum(a,b),cc)*N).astype(int)
    xs,ys=np.meshgrid(np.arange(max(lo_[0],0),min(hi_[0]+1,N)),np.arange(max(lo_[1],0),min(hi_[1]+1,N)))
    q=np.stack([(xs.ravel()+0.5)/N,(ys.ravel()+0.5)/N],1)
    if len(q)==0: continue
    tri=np.array([[a[0],a[1],0],[b[0],b[1],0],[cc[0],cc[1],0]])
    bc=points_to_barycentric(np.repeat(tri[None],len(q),0), np.c_[q,np.zeros(len(q))])
    ok=(bc>=-0.02).all(1)
    if not ok.any(): continue
    bc=bc[ok]; P=(bc[:,:,None]*lo.vertices[F[fi]][None]).sum(1)
    pts.append(P); pix.append(np.stack([xs.ravel()[ok],ys.ravel()[ok]],1))
pts=np.concatenate(pts); pix=np.concatenate(pix)
cp,_,tid=trimesh.proximity.closest_point(hi,pts)
hbc=points_to_barycentric(hi.triangles[tid],cp)
huv=(hbc[:,:,None]*hi.visual.uv[hi.faces[tid]]).sum(1)
px=np.clip((huv[:,0]%1)*TW,0,TW-1).astype(int); py=np.clip((1-huv[:,1]%1)*TH,0,TH-1).astype(int)
col=src_tex[py,px]
img[N-1-pix[:,1],pix[:,0]]=col; filled[N-1-pix[:,1],pix[:,0]]=True
# заполнить пустые текселы соседями (чтобы не было чёрных швов)
from scipy import ndimage
idx=ndimage.distance_transform_edt(~filled,return_distances=False,return_indices=True)
img=img[idx[0],idx[1]]
tex=Image.fromarray(img); tex.save(f'{W}/web/{name}_128.png')
lo.visual=trimesh.visual.TextureVisuals(uv=uv,material=trimesh.visual.material.PBRMaterial(baseColorTexture=tex,metallicFactor=0,roughnessFactor=1))
lo.export(f'{W}/{name}.glb')
print(name,'src',len(hi.faces),'-> tris',len(lo.faces),'size m',[round(float(v),3) for v in lo.extents])
