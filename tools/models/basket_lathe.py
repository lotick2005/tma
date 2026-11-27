# Корзина: тело вращения по замеренному профилю + две ручки-тора, текстура запекается с исходника.
import sys, numpy as np, trimesh
from PIL import Image
from scipy import ndimage
from trimesh.triangles import points_to_barycentric
W=sys.argv[1] if len(sys.argv)>1 else 'props'; longest=0.42
s=trimesh.load(f'{W}/src/basket.glb'); hi=list(s.geometry.values())[0]
c=hi.bounds.mean(axis=0); hi.apply_translation([-c[0],-hi.bounds[0][1],-c[2]]); hi.apply_scale(longest/max(hi.extents))
v=hi.vertices; r=np.hypot(v[:,0],v[:,2]); H=v[:,1].max()
# высота края — по 90-му перцентилю высоты точек на большом радиусе (без ручек)
rim_h=np.percentile(v[r>np.percentile(r,60)][:,1],97)
K=6; hs=np.linspace(0.0,rim_h,K)
prof=[]
for h in hs:
    sel=np.abs(v[:,1]-h)<rim_h/(K*1.5); prof.append(np.percentile(r[sel],90) if sel.sum()>50 else None)
prof=[p if p is not None else prof[i-1] for i,p in enumerate(prof)]
prof[0]*=0.97
SEG=14; t=0.015
ang=np.linspace(0,2*np.pi,SEG,endpoint=False)
verts=[];faces=[]
def ring(rad,h):
    i=len(verts); verts.extend([[rad*np.cos(a),h,rad*np.sin(a)] for a in ang]); return i
outer=[ring(p,h) for p,h in zip(prof,hs)]
inner=[ring(max(p-t,0.01),h+ (t if k==0 else 0)) for k,(p,h) in enumerate(zip(prof,hs))]
def strip(a,b,flip=False):
    for j in range(SEG):
        q=[a+j,a+(j+1)%SEG,b+(j+1)%SEG,b+j]
        f=[[q[0],q[1],q[2]],[q[0],q[2],q[3]]]
        faces.extend([x[::-1] for x in f] if flip else f)
for k in range(K-1): strip(outer[k],outer[k+1],True); strip(inner[k],inner[k+1])
strip(outer[-1],inner[-1],True)  # край
cb=len(verts); verts.append([0,0,0]); ci=len(verts); verts.append([0,t,0])
for j in range(SEG):
    faces.append([cb,outer[0]+j,outer[0]+(j+1)%SEG]); faces.append([ci,inner[0]+(j+1)%SEG,inner[0]+j])
body=trimesh.Trimesh(np.array(verts),np.array(faces),process=True)
parts=[body]
for sx in (1,-1):
    tor=trimesh.creation.torus(major_radius=0.035,minor_radius=0.008,major_sections=8,minor_sections=4)
    tor.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[1,0,0]))
    tor.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[0,1,0]))
    tor.apply_translation([sx*(prof[-1]+0.005),rim_h+0.02,0])
    parts.append(tor)
lo=trimesh.util.concatenate(parts).unwrap()
uv=lo.visual.uv; N=128; src_tex=np.asarray(hi.visual.material.baseColorTexture.convert('RGB')); TH,TW=src_tex.shape[:2]
img=np.zeros((N,N,3),np.uint8); filled=np.zeros((N,N),bool); F=lo.faces; pts=[];pix=[]
for fi,(a,b,cc) in enumerate(uv[F]):
    l=np.floor(np.minimum(np.minimum(a,b),cc)*N).astype(int); h_=np.ceil(np.maximum(np.maximum(a,b),cc)*N).astype(int)
    xs,ys=np.meshgrid(np.arange(max(l[0],0),min(h_[0]+1,N)),np.arange(max(l[1],0),min(h_[1]+1,N)))
    q=np.stack([(xs.ravel()+0.5)/N,(ys.ravel()+0.5)/N],1)
    if not len(q): continue
    tri=np.array([[a[0],a[1],0],[b[0],b[1],0],[cc[0],cc[1],0]])
    bc=points_to_barycentric(np.repeat(tri[None],len(q),0),np.c_[q,np.zeros(len(q))]); ok=(bc>=-0.02).all(1)
    if not ok.any(): continue
    pts.append((bc[ok][:,:,None]*lo.vertices[F[fi]][None]).sum(1)); pix.append(np.stack([xs.ravel()[ok],ys.ravel()[ok]],1))
pts=np.concatenate(pts); pix=np.concatenate(pix)
cp,_,tid=trimesh.proximity.closest_point(hi,pts); hbc=points_to_barycentric(hi.triangles[tid],cp)
huv=(hbc[:,:,None]*hi.visual.uv[hi.faces[tid]]).sum(1)
px=np.clip((huv[:,0]%1)*TW,0,TW-1).astype(int); py=np.clip((1-huv[:,1]%1)*TH,0,TH-1).astype(int)
img[N-1-pix[:,1],pix[:,0]]=src_tex[py,px]; filled[N-1-pix[:,1],pix[:,0]]=True
idx=ndimage.distance_transform_edt(~filled,return_distances=False,return_indices=True); img=img[idx[0],idx[1]]
tex=Image.fromarray(img); tex.save(f'{W}/web/basket_128.png')
lo.visual=trimesh.visual.TextureVisuals(uv=uv,material=trimesh.visual.material.PBRMaterial(baseColorTexture=tex,metallicFactor=0,roughnessFactor=1))
lo.export(f'{W}/basket.glb'); print('basket tris',len(lo.faces),'size',[round(float(x),3) for x in lo.extents],'rim',round(rim_h,3))
