"""Blender stage: refine the existing cat, preserve weights, reduce and unwrap.
Run Blender -b --python this_file -- --source <previous anatomy folder>.
The resulting intermediate is consumed by paint_calico.py. Never builds a new rig.
"""
import bpy, numpy as np, json, sys, math, argparse
from pathlib import Path

args=argparse.ArgumentParser()
args.add_argument('--source',required=True)
opt=args.parse_args(sys.argv[sys.argv.index('--')+1:])
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/authoring'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
SOURCE=Path(opt.source)
data=json.loads((SOURCE/'calico_anatomy.json').read_text())
assert data.get('version',2)<3, 'Use the backed-up original anatomy, not an already refined mesh.'
blob=(SOURCE/'calico_anatomy.bin').read_bytes()
def read(s,key,dtype,columns):
    a,b=s[key]
    return np.frombuffer(blob[a:a+b],dtype=dtype).copy().reshape(-1,columns)

def reshape(v):
    v=np.asarray(v,dtype=np.float32).copy()
    z=v[:,2].copy(); y=v[:,1].copy()
    head=np.clip((-z-.175)/.09,0,1)
    v[:,0]*=1-.20*head
    # Relax the old arched rump, lift the neck/head to a natural standing posture.
    v[:,1]-=.026*np.exp(-((z-.17)/.21)**2)*np.clip((y-.10)/.19,0,1)
    v[:,1]-=.014*np.exp(-((z+.14)/.065)**2)*np.clip((y-.20)/.09,0,1)
    v[:,1]+=.028*head*np.clip((y-.19)/.07,0,1)
    return v

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
result={}; objects=[]
for s in data['surfaces']:
    name=s['name']; v=read(s,'positions','<f4',3)
    faces=read(s,'indices_data','<i4',3)[:,[0,2,1]]
    joints=read(s,'joints','<i4',4); weights=read(s,'weights','<f4',4)
    v=reshape(v)
    if name=='coat':
        tail_weight=(weights*(joints>=34)).sum(1)
        tail_root=reshape([data['bones'][34]['position']])[0]
        v=tail_root+(v-tail_root)*(1-tail_weight[:,None]*(1-.30/.3437458454))
    if name in ('eye','lid','iris','pupil','glint'):
        v[:,2]+=.003
    if name=='iris':
        centers=np.where(v[:,0]<0,-.052,.052)*.8
        v[:,0]=centers+(v[:,0]-centers)*1.55
    if name=='lid':
        v[:,1]=.337+(v[:,1]-.337)*.90
    if name=='nose':
        v[:,0]*=np.clip(.65+(v[:,1]-.290)*36,.45,1)
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(v.tolist(),[],faces.tolist()); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    for b in data['bones']:obj.vertex_groups.new(name=b['name'])
    for i in range(len(v)):
        for j,w in zip(joints[i],weights[i]):
            if w>1e-7:obj.vertex_groups[int(j)].add([i],float(w),'REPLACE')
    if name=='coat':
        mod=obj.modifiers.new('Relax continuous surface','SMOOTH');mod.factor=.28;mod.iterations=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if name!='whisker':
        mod=obj.modifiers.new('Realtime silhouette budget','DECIMATE')
        mod.ratio=.27 if name=='coat' else .40
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in obj.data.polygons:p.use_smooth=True
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(68),island_margin=.008,area_weight=.3,scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh=obj.data; mesh.calc_loop_triangles();mesh.calc_tangents()
    # Split only at UV seams, retain smooth normals and skinning.
    remap={}; vv=[]; nn=[]; uu=[]; jj=[]; ww=[]; tt=[]; ff=[]
    for tri in mesh.loop_triangles:
        face=[]
        for li in tri.loops:
            loop=mesh.loops[li];vi=loop.vertex_index;uv=mesh.uv_layers.active.data[li].uv
            key=(vi,round(uv.x,7),round(uv.y,7))
            if key not in remap:
                remap[key]=len(vv);vert=mesh.vertices[vi]
                vv.append(tuple(vert.co));nn.append(tuple(loop.normal));uu.append((uv.x,1-uv.y))
                influences=sorted([(g.group,g.weight) for g in vert.groups],key=lambda a:-a[1])[:4]
                influences += [(0,0)]*(4-len(influences));total=sum(w for j,w in influences)
                jj.append([j for j,w in influences]);ww.append([w/total for j,w in influences])
                tt.append((*loop.tangent,-loop.bitangent_sign))
            face.append(remap[key])
        ff.append(face)
    for key,value in dict(v=vv,n=nn,uv=uu,j=jj,w=ww,t=tt,f=ff).items():
        result[name+'_'+key]=np.asarray(value,dtype='i4' if key in ('j','f') else 'f4')
    print('REFINED',name,len(vv),'vertices',len(ff),'triangles',flush=True)
    obj.select_set(False);objects.append(obj)
# Small closed meshes for pads, bound to their existing paw bones.
vv=[];nn=[];uu=[];jj=[];ww=[];tt=[];ff=[]
for leg in data['legs']:
    center=np.array(leg['points'][4]);bone_id=leg['bones'][4]
    for dx,dz,rx,rz in [(0,.005,.017,.020),(-.018,-.024,.006,.008),(-.006,-.028,.006,.008),(.006,-.028,.006,.008),(.018,-.024,.006,.008)]:
        c=center+[dx,-.019,dz];offset=len(vv)
        for r in range(9):
            phi=math.pi*r/8
            for j in range(16):
                angle=2*math.pi*j/16;p=np.array([math.sin(phi)*math.cos(angle),math.cos(phi),math.sin(phi)*math.sin(angle)])
                vv.append(reshape([c+p*np.array([rx,.002,rz])])[0]);nn.append(p);uu.append([j/15,r/8])
                jj.append([bone_id,0,0,0]);ww.append([1,0,0,0]);tt.append([1,0,0,1])
        for r in range(8):
            for j in range(15):
                a=offset+r*16+j;b=a+1;c=a+16;d=c+1
                ff.extend([[a,b,c],[b,d,c]])
for key,value in dict(v=vv,n=nn,uv=uu,j=jj,w=ww,t=tt,f=ff).items():
    result['pads_'+key]=np.asarray(value,dtype='i4' if key in ('j','f') else 'f4')
for b in data['bones']:b['position']=reshape([b['position']])[0].tolist()
tail_root=np.array(data['bones'][34]['position'])
for i in data['tail_bones']:
    data['bones'][i]['position']=(tail_root+(np.array(data['bones'][i]['position'])-tail_root)*(.30/.3437458454)).tolist()
for leg in data['legs']:leg['points']=reshape(leg['points']).tolist()
data['version']=3
data['authoring']='Blender refined original continuous mesh / UV atlas / existing 47-bone rig'
(OUT/'calico_uv_rig.json').write_text(json.dumps(data),encoding='utf8')
np.savez_compressed(OUT/'calico_uv_source.npz',**result)
print('BLENDER_UV_READY',flush=True)
