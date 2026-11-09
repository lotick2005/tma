# Сведение фото-текстур Poly Haven в одну палитру: меньше цвета, ровный контраст, меньше мелкого шума,
# 16 цветов без дизеринга (как CLUT на PS1). Средний цвет потом задаёт материал (ProcTextures.photo_tint).
# Запуск: python3 tools/textures/grade_photos.py <папка исходников 128×128> textures/photo
# Исходники до сведения — в коммите cf78115 (git show cf78115:textures/photo/<имя>.png).
import sys, os, numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
src, dst = sys.argv[1], sys.argv[2]
# имя: (разброс яркости, доля крупных пятен, сглаживание мелочи в пикселях, сколько своего цвета оставить, оттенок)
os.makedirs(dst, exist_ok=True)
STONE=(0.075,0.5,0.7,0.25,(1.0,0.96,0.88))
P = {
 "white_stucco_02":(0.025,0.4,0.6,0.2,(1.0,0.98,0.93)),
 "rough_plaster_03":(0.03,0.35,1.1,0.15,(1.0,0.96,0.88)),
 "white_rough_plaster":(0.06,0.35,0.7,0.2,(1.0,0.96,0.88)),
 "clay_block_wall":(0.06,0.35,0.7,0.3,(1.0,0.9,0.75)),
 "rock_wall_04":(0.10,0.5,0.6,0.15,(1.0,0.95,0.86)),
 "rustic_stone_wall_02":(0.10,0.5,0.6,0.2,(1.0,0.95,0.86)),
 "rock_wall_06":(0.08,0.5,0.6,0.2,(1.0,0.96,0.9)),
 "rock_wall_03":(0.08,0.5,0.6,0.2,(1.0,0.96,0.9)),
 "gravelly_sand":(0.055,0.35,0.8,0.25,(1.0,0.93,0.82)),
 "dirt_floor":(0.055,0.35,0.8,0.25,(1.0,0.93,0.82)),
 "dry_ground_rocks":(0.08,0.5,0.7,0.25,(1.0,0.93,0.82)),
 "rocky_terrain_03":(0.09,0.5,0.6,0.3,(1.0,0.95,0.85)),
 "dark_wooden_planks":(0.12,0.5,0.4,0.5,(1.0,0.85,0.7)),
 "old_wood_floor":(0.12,0.5,0.4,0.5,(1.0,0.85,0.7)),
 "hessian_230":(0.08,0.4,0.4,0.4,(1.0,0.92,0.78)),
 "hessian_380":(0.08,0.4,0.4,0.4,(1.0,0.92,0.78)),
 "jogging_melange":(0.06,0.4,0.4,0.2,(1.0,0.98,0.94)),
}
def lum(a): return a@np.array([0.299,0.587,0.114])
for f in sorted(os.listdir(src)):
    if not f.endswith(".png"): continue
    n=f[:-4]; std_t,lowk,sm,ck,tint=P.get(n,STONE)
    a=np.asarray(Image.open(os.path.join(src,f)).convert("RGB")).astype(float)/255
    L=lum(a); m=L.mean()
    Ls=gaussian_filter(L,sm,mode="wrap")              # убрать пиксельный шум
    low=gaussian_filter(L,6,mode="wrap")              # крупные пятна
    det=Ls-low; lv=low-m
    raw=lowk*lv + det                                  # крупные пятна приглушены (меньше видно повтор)
    Lo=0.5*(1+(raw/max(raw.std(),1e-4))*std_t/0.5)
    chroma=a-L[...,None]
    chroma=gaussian_filter(chroma,(1.5,1.5,0),mode="wrap")
    out=Lo[...,None]*np.array(tint)/np.mean(tint)+ck*chroma*(0.5/max(m,0.1))
    out=np.clip(out,0,1)
    im=Image.fromarray((out*255+0.5).astype(np.uint8))
    im=im.quantize(16,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert("RGB")
    im.save(os.path.join(dst,f),optimize=True)
    print(n, round(m,3), "->", round(float(lum(np.asarray(im)/255.).std()),3))
