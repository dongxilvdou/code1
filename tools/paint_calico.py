"""Bake deterministic, surface-aligned calico fur into the Blender UV atlas.
No hair particles; three atlases share a compact four-influence, 47-bone skin.
Input is the Blender-authored calico_uv_source.npz, not a reference-sheet texture.
"""
from pathlib import Path
import json, numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter

ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/models'; TEX=OUT/'textures'
TEX.mkdir(exist_ok=True)
source=np.load(OUT/'authoring/calico_uv_source.npz')
data=json.loads((OUT/'authoring/calico_uv_rig.json').read_text())
GROUPS={'coat':['coat'],'features':['lid','inner_ear','whisker','claw','nose','mouth','pads'], 'eyes':['eye','iris','pupil','glint']}

def smooth(x):
    x=np.clip(x,0,1);return x*x*(3-2*x)
def hash3(p):
    return np.mod(np.sin(p[:,0]*127.1+p[:,1]*311.7+p[:,2]*74.7)*43758.5453,1)
def shade(p,part,tail):
    n=len(p); x,y,z=p.T
    cream=np.array([.91,.882,.817]);orange=np.array([.70,.377,.145]);black=np.array([.095,.086,.077])
    rgb=np.tile(cream,(n,1));h=np.full(n,.5);rough=np.full(n,.84)
    if part=='coat':
        ripple=.12*np.sin(x*109+y*41)*np.cos(z*77)+.055*np.sin(z*213+y*143+x*187)
        orange_amount=np.zeros(n)
        patches=[((-.082,.276,.085),(.075,.108,.112),black),
                 ((-.065,.285,.205),(.085,.084,.087),orange),
                 ((.083,.272,.046),(.074,.095,.099),orange),
                 ((.083,.255,.175),(.063,.092,.083),black),
                 ((.015,.331,-.070),(.082,.058,.103),orange),
                 ((-.041,.330,.000),(.067,.055,.060),black),
                 ((.029,.329,.230),(.079,.062,.069),black),
                 ((-.061,.347,-.289),(.067,.077,.085),black),
                 ((.060,.347,-.290),(.072,.078,.086),orange)]
        for c,r,col in patches:
            d=np.sum(((p-c)/r)**2,axis=1)+ripple
            a=smooth((1-d)/.095)
            rgb=rgb*(1-a[:,None])+col*a[:,None]
            orange_amount=orange_amount*(1-a)+(a if col is orange else 0)
        # White bib, entire lower limbs and a widening asymmetric facial blaze.
        bib=smooth((.20-y)/.035)
        face=(z<-.333)&(y<.39)
        blaze=smooth((.012+np.maximum(0,.364-y)*.41-np.abs(x+.004))/.005)*face
        muzzle=smooth((.312-y)/.012)*(z<-.337)
        white=np.maximum.reduce([bib,blaze,muzzle])
        rgb=rgb*(1-white[:,None])+cream*white[:,None];orange_amount*=1-white
        ears=(y>.379)&(z<-.235)
        rgb[ears&(x<0)]=black;rgb[ears&(x>=0)]=orange
        orange_amount[ears]=(x[ears]>=0)
        # Tail uses its actual skeleton arc coordinate, preserving rings around the tube.
        tail_points=np.array([data['bones'][i]['position'] for i in data['tail_bones']])
        t=np.zeros(n);best=np.full(n,100.)
        for i in range(len(tail_points)-1):
            a=tail_points[i];ab=tail_points[i+1]-a
            s=np.clip(((p-a)*ab).sum(1)/(ab*ab).sum(),0,1)
            d=((p-a-s[:,None]*ab)**2).sum(1);take=d<best
            t[take]=(i+s[take])/12;best[take]=d[take]
        rings=(np.sin(t*5.5*np.pi+.7)>.08).astype(float)
        trgb=orange[None,:]*(1-rings[:,None])+black[None,:]*rings[:,None]
        tip=smooth((t-.87)/.045);trgb=trgb*(1-tip[:,None])+cream*tip[:,None]
        rgb=np.where(tail[:,None]>.5,trgb,rgb)
        orange_amount=np.where(tail>.5,(1-rings)*(1-tip),orange_amount)
        # Fine directional strands plus restrained tabby marks in orange patches.
        warp=np.sin(y*71+z*19)*.0008
        grain=hash3(np.column_stack((np.floor((x+warp)*5500),np.floor(y*1900),np.floor(z*1450))))
        strands=np.sin((x+warp)*17800+np.sin(y*150+z*33)*2)*.5+.5
        h=.5+.15*(grain-.5)+.11*(strands-.5)
        tabby=smooth((np.sin(z*160+y*52+np.sin(x*48)*1.8)-.30)/.6)
        rgb*=((.97+.10*(grain-.5)+.065*(strands-.5))*(1-.055*tabby*orange_amount))[:,None]
        rough=.82+.08*grain
    elif part=='iris':
        cx=np.where(x<0,-.052,.052)*.8
        a=np.arctan2(y-.337,x-cx);r=np.sqrt(((x-cx)/.0155)**2+((y-.337)/.011)**2)
        fibers=(np.sin(a*113+np.sin(a*31)*2)+np.sin(a*227+r*13))*.5
        rgb=np.tile([.54,.49,.205],(n,1))*(.86+.15*fibers[:,None])
        rgb*= (1-.45*smooth((r-.8)/.25))[:,None];rough[:]=.22
    else:
        color={'lid':[.115,.081,.064],'eye':[.41,.375,.155],'pupil':[.007,.009,.007],
               'glint':[.94,.98,.92],'inner_ear':[.76,.43,.40],'nose':[.70,.34,.34],
               'whisker':[.86,.84,.76],'claw':[.67,.59,.49],'mouth':[.19,.095,.083],'pads':[.66,.32,.33]}[part]
        rgb=np.tile(color,(n,1));rough[:]=.68 if part not in ('eye','pupil','glint') else .15
        if part in ('inner_ear','nose'):
            grain=hash3(np.floor(p*10000));rgb*= (.95+.09*grain)[:,None];h=.5+.04*(grain-.5)
            if part=='inner_ear':rgb*= (.88+.12*smooth((y-.375)/.045))[:,None]
    return np.clip(rgb,0,1),h,rough

blob=bytearray();surfaces=[]
def write(a,dtype):
    b=np.asarray(a,dtype=dtype).tobytes();span=[len(blob),len(b)];blob.extend(b);return span
for group,parts in GROUPS.items():
    size=4096 if group=='coat' else 1024
    rgb=np.zeros((size,size,3),np.float32);height=np.full((size,size),.5,np.float32)
    rough=np.full((size,size),.85,np.float32);valid=np.zeros((size,size),bool)
    merged={k:[] for k in ('v','n','uv','j','w','t','f')};offset=0
    columns=1 if group=='coat' else 2;rows=int(np.ceil(len(parts)/columns))
    for part_index,part in enumerate(parts):
        a={k:source[part+'_'+k].copy() for k in merged}
        uv=a['uv']*.94+.03
        uv[:,0]=(uv[:,0]+part_index%columns)/columns;uv[:,1]=(uv[:,1]+part_index//columns)/rows
        a['uv']=uv
        tail=(a['w']*(a['j']>=34)).sum(1)
        # Rasterize original surface positions, so seams sample identical fur and patch boundaries.
        for tri in a['f']:
            q=uv[tri]*(size-1);mn=np.maximum(np.floor(q.min(0)).astype(int),0);mx=np.minimum(np.ceil(q.max(0)).astype(int),size-1)
            xx,yy=np.meshgrid(np.arange(mn[0],mx[0]+1),np.arange(mn[1],mx[1]+1))
            den=(q[1,1]-q[2,1])*(q[0,0]-q[2,0])+(q[2,0]-q[1,0])*(q[0,1]-q[2,1])
            if abs(den)<1e-10:continue
            u=((q[1,1]-q[2,1])*(xx-q[2,0])+(q[2,0]-q[1,0])*(yy-q[2,1]))/den
            v=((q[2,1]-q[0,1])*(xx-q[2,0])+(q[0,0]-q[2,0])*(yy-q[2,1]))/den
            inside=(u>=-1e-5)&(v>=-1e-5)&(u+v<=1.00001)
            if not inside.any():continue
            weights=np.column_stack((u[inside],v[inside],1-u[inside]-v[inside]))
            p=weights@a['v'][tri];t=weights@tail[tri]
            color,h,r=shade(p,part,t)
            xx=xx[inside];yy=yy[inside];rgb[yy,xx]=color;height[yy,xx]=h;rough[yy,xx]=r;valid[yy,xx]=True
        for k in merged:merged[k].append(a[k]+offset if k=='f' else a[k])
        offset+=len(a['v'])
        print('PAINTED',group,part,flush=True)
    # Extend every island by nearest texel to keep mipmap seams clean.
    idx=distance_transform_edt(~valid,return_distances=False,return_indices=True)
    rgb=rgb[tuple(idx)];height=height[tuple(idx)];rough=rough[tuple(idx)]
    gy,gx=np.gradient(gaussian_filter(height,.45))
    normal=np.stack((-gx*1.8,gy*1.8,np.ones_like(gx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
    Image.fromarray(np.uint8(np.clip(rgb*255,0,255))).save(TEX/f'calico_{group}_basecolor.png')
    Image.fromarray(np.uint8((normal*.5+.5)*255)).save(TEX/f'calico_{group}_normal.png')
    Image.fromarray(np.uint8(rough*255)).save(TEX/f'calico_{group}_roughness.png')
    a={k:np.concatenate(v) for k,v in merged.items()}
    surfaces.append(dict(name=group,vertices=len(a['v']),indices=a['f'].size,
        positions=write(a['v'],'<f4'),normals=write(a['n'],'<f4'),uv=write(a['uv'],'<f4'),
        colors=write(np.ones((len(a['v']),4)),'<f4'),joints=write(a['j'],'<i4'),weights=write(a['w'],'<f4'),
        tangents=write(a['t'],'<f4'),indices_data=write(a['f'][:,[0,2,1]],'<i4')))
    print('ATLAS_READY',group,size,flush=True)
stats=dict(vertices=sum(s['vertices'] for s in surfaces),triangles=sum(s['indices']//3 for s in surfaces),bones=47,surfaces=3,
           authoring='Blender 5.2.2: continuous original mesh, sculpt adjustment, decimation, UV unwrap; surface-space atlas bake',
           textures='4096 coat + 1024 features + 1024 eyes; Base Color / Normal / Roughness',
           source_weight_error=float(max(abs(source[k].sum(1)-1).max() for k in source.files if k.endswith('_w'))))
data.update(surfaces=surfaces,stats=stats)
(OUT/'calico_anatomy.bin').write_bytes(blob)
(OUT/'calico_anatomy.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
(OUT/'model_report.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
print(json.dumps(stats,indent=2),flush=True)
