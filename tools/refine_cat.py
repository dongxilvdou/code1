"""Author an anatomical, continuous, high density skinned cat using NumPy/SciPy.

The supplied reference informs silhouette and stretch pose. No external asset is used.
Units: metres; forward: -Z; coordinates are authored in the final proportions.
"""
from pathlib import Path
import json, math
import numpy as np
from scipy.interpolate import CubicSpline
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'models'
OUT.mkdir(parents=True,exist_ok=True)
BONES=[]; IDX={}; PARTS={}
def bone(name,parent,pos):
    i=len(BONES); IDX[name]=i
    BONES.append(dict(name=name,parent=IDX.get(parent,-1),position=list(pos)))
    return i

bone('root',None,(0,0,0))
bone('pelvis','root',(0,.252,.193))
bone('lumbar','pelvis',(0,.259,.092))
bone('thorax','lumbar',(0,.250,-.043))
bone('chest','thorax',(0,.241,-.142))
bone('neck','chest',(0,.268,-.212))
bone('head','neck',(0,.291,-.287))
bone('jaw','head',(0,.257,-.347))
bone('ear_L','head',(-.065,.347,-.285))
bone('ear_R','head',(.065,.347,-.285))
LEGS=[]
for front in [True,False]:
    for side in [-1,1]:
        suffix='L' if side<0 else 'R'; pre='front' if front else 'rear'
        x=side*(.082 if front else .086)
        if front:
            names=['scapula','upper','forearm','wrist','paw','toes']
            pts=[(x,.244,-.143),(x,.214,-.158),(x,.127,-.141),(x,.044,-.174),(x,.021,-.213),(x,.019,-.242)]
            parent='chest'
        else:
            names=['hip','upper','shin','hock','paw','toes']
            pts=[(x,.239,.187),(x,.213,.181),(x,.132,.103),(x,.060,.205),(x,.021,.140),(x,.019,.108)]
            parent='pelvis'
        indices=[]
        for name,p in zip(names,pts):
            label=f'{pre}_{name}_{suffix}'
            indices.append(bone(label,parent,p));parent=label
        LEGS.append(dict(front=front,side=side,bones=indices,points=pts))

tail_controls=np.array([[0,.302,.283],[0,.334,.332],[0,.391,.355],[0,.456,.340],[0,.494,.301],[0,.502,.253],[0,.485,.207]],float)
curve=CubicSpline(np.linspace(0,1,len(tail_controls)),tail_controls,axis=0)
tail_points=curve(np.linspace(0,1,13))
tail_ids=[]
for i,p in enumerate(tail_points):tail_ids.append(bone(f'tail_{i:02d}','pelvis' if i==0 else f'tail_{i-1:02d}',p))

CREAM=np.array([.77,.725,.64]); ORANGE=np.array([.49,.245,.105]); BLACK=np.array([.047,.055,.051])
def coat(v):
    color=np.tile(CREAM,(len(v),1))
    patches=[
        ((-.071,.266,.090),(.110,.128,.153),BLACK),
        ((.079,.279,.104),(.075,.126,.123),ORANGE),
        ((.047,.293,.254),(.079,.120,.093),BLACK),
        ((-.033,.330,-.048),(.088,.058,.132),ORANGE),
        ((-.071,.292,-.285),(.066,.094,.097),ORANGE),
        ((.067,.312,-.285),(.066,.085,.095),BLACK),
        ((-.082,.152,-.152),(.034,.100,.052),ORANGE),
        ((.082,.152,-.149),(.033,.102,.052),BLACK),
        ((-.086,.184,.171),(.055,.072,.074),ORANGE),
    ]
    ripple=.07*np.sin(v[:,0]*117+v[:,1]*52)*np.cos(v[:,2]*91)+.045*np.sin(v[:,2]*187+v[:,1]*118)
    for c,r,col in patches:
        d=np.sum(((v-c)/r)**2,axis=1)+ripple
        edge=np.clip((1.0-d)/.065,0,1)
        color=color*(1-edge[:,None])+col*edge[:,None]
    blaze=(np.abs(v[:,0])<(.013+.11*np.maximum(0,.29-v[:,1])))&(v[:,2]<-.333)
    color[blaze]=CREAM
    ears=(v[:,1]>.347)&(v[:,2]<-.235)
    color[ears&(v[:,0]<0)]=ORANGE
    color[ears&(v[:,0]>=0)]=BLACK
    paws=np.clip((.058-v[:,1])/.017,0,1)
    color=color*(1-paws[:,None])+CREAM*paws[:,None]
    tooth=.987+.013*np.sin(v[:,0]*1693+np.sin(v[:,2]*1104))*np.sin(v[:,1]*1371)
    return np.column_stack((color*tooth[:,None],np.ones(len(v)))).astype('f4')

def segment_distance(v,a,b):
    ab=np.asarray(b)-a
    t=np.clip(np.sum((v-a)*ab,axis=1)/max(np.dot(ab,ab),1e-12),0,1)
    return np.linalg.norm(v-(a+t[:,None]*ab),axis=1)

def weights(v,kind='body',bind=None):
    n=len(v)
    if bind is not None:
        j=np.zeros((n,4),dtype='i4');w=np.zeros((n,4),dtype='f4');j[:,0]=bind;w[:,0]=1
        return j,w
    if kind=='tail':
        dist=np.stack([segment_distance(v,tail_points[i],tail_points[i+1]) for i in range(12)],axis=1)
        seg=np.argmin(dist,axis=1)
        a=tail_points[seg]; b=tail_points[seg+1]; ab=b-a
        t=np.clip(np.sum((v-a)*ab,axis=1)/np.sum(ab*ab,axis=1),0,1)
        j=np.zeros((n,4),dtype='i4');w=np.zeros((n,4),dtype='f4')
        j[:,0]=np.array(tail_ids)[seg];j[:,1]=np.array(tail_ids)[seg+1]
        w[:,0]=1-t;w[:,1]=t
        return j,w
    scores=np.full((n,len(BONES)),-80.,dtype='f4')
    for name,sigma in [('pelvis',(.14,.14,.094)),('lumbar',(.13,.12,.105)),('thorax',(.13,.11,.09)),('chest',(.105,.11,.09)),('neck',(.075,.075,.07)),('head',(.10,.080,.080))]:
        i=IDX[name]; p=np.array(BONES[i]['position'])
        scores[:,i]=-np.sum(((v-p)/sigma)**2,axis=1)*2.0
    scores[:,IDX['jaw']]=-np.sum(((v-BONES[IDX['jaw']]['position'])/(.055,.028,.053))**2,axis=1)*2.5-1.5
    for leg in LEGS:
        ids=leg['bones'];pts=np.array(leg['points'])
        for k in range(6):
            a=pts[k];b=pts[min(k+1,5)]+(np.array([0,0,-.013]) if k==5 else 0)
            radius=[.055,.042,.033,.027,.032,.022][k]
            scores[:,ids[k]]=-(segment_distance(v,a,b)/radius)**2*2.8-.55
            scores[:,ids[k]]-=np.clip((v[:,1]-.24)/.015,0,8)
    for side,name in [(-1,'ear_L'),(1,'ear_R')]:
        p=np.array(BONES[IDX[name]]['position'])+[side*.006,.025,.003]
        scores[:,IDX[name]]=-np.sum(((v-p)/(.033,.056,.028))**2,axis=1)*2
    take=np.argpartition(scores,-4,axis=1)[:,-4:]
    selected=np.take_along_axis(scores,take,axis=1)
    w=np.exp(selected-np.max(selected,axis=1)[:,None]);w/=w.sum(axis=1)[:,None]
    # Keep pads planted and rigid locally; blend into the articulated wrist above.
    feet=np.array([leg['points'][4] for leg in LEGS])
    closest=np.argmin(np.sum((v[:,None,[0,2]]-feet[None,:,[0,2]])**2,axis=2),axis=1)
    paw_ids=np.array([leg['bones'][4] for leg in LEGS])[closest]
    toe_ids=np.array([leg['bones'][5] for leg in LEGS])[closest]
    alpha=np.clip((.067-v[:,1])/.030,0,1)
    toe_mix=np.clip((feet[closest,2]-v[:,2]+.01)/.045,.12,.65)
    candidates=np.column_stack((take,paw_ids,toe_ids))
    cw=np.column_stack((w*(1-alpha[:,None]),alpha*(1-toe_mix),alpha*toe_mix))
    best=np.argsort(cw,axis=1)[:,-4:]
    take=np.take_along_axis(candidates,best,axis=1)
    w=np.take_along_axis(cw,best,axis=1);w/=w.sum(axis=1)[:,None]
    face=(v[:,2]<-.327)&(v[:,1]>.278)
    take[face,0]=IDX['head'];w[face]=[1,0,0,0]
    return take.astype('i4'),w.astype('f4')

def add(name,v,f,n,material='coat',kind='body',bind=None,colors=None,uv=None):
    v=np.asarray(v,dtype='f4');f=np.asarray(f,dtype='i4');n=np.asarray(n,dtype='f4')
    j,w=weights(v,kind,bind)
    if colors is None:colors=coat(v) if material=='coat' else np.ones((len(v),4),dtype='f4')
    if uv is None:uv=np.column_stack((np.arctan2(v[:,0],v[:,1]-.25)/math.tau+.5,v[:,2]*2+.5)).astype('f4')
    PARTS.setdefault(material,[]).append(dict(name=name,v=v,f=f,n=n,j=j,w=w,c=colors,uv=uv))

def organic_body(pitch=.0053):
    lower=np.array([-.166,-.008,-.418]);upper=np.array([.166,.441,.347])
    axes=[np.arange(a,b+pitch,pitch,dtype='f4') for a,b in zip(lower,upper)]
    X,Y,Z=np.meshgrid(*axes,indexing='ij');shape=X.shape
    field=np.full(shape,1,dtype='f4')
    def union(d,k=.014):
        nonlocal field
        h=np.clip(.5+.5*(d-field)/k,0,1)
        field=d*(1-h)+field*h-k*h*(1-h)
    def ellipsoid(c,r,k=.015):
        px=(X-c[0])/r[0];py=(Y-c[1])/r[1];pz=(Z-c[2])/r[2]
        a=np.sqrt(px*px+py*py+pz*pz)
        b=np.sqrt((px/r[0])**2+(py/r[1])**2+(pz/r[2])**2)
        union(a*(a-1)/np.maximum(b,1e-5),k)
    def capsule(a,b,r1,r2,k=.012):
        a=np.array(a);b=np.array(b);ab=b-a
        t=np.clip(((X-a[0])*ab[0]+(Y-a[1])*ab[1]+(Z-a[2])*ab[2])/np.dot(ab,ab),0,1)
        d=np.sqrt((X-a[0]-t*ab[0])**2+(Y-a[1]-t*ab[1])**2+(Z-a[2]-t*ab[2])**2)-(r1+(r2-r1)*t)
        union(d,k)
    ellipsoid((0,.246,.062),(.106,.103,.208),.021)
    ellipsoid((0,.237,-.064),(.101,.101,.130),.022)
    ellipsoid((0,.255,.197),(.107,.115,.116),.021)
    ellipsoid((0,.262,-.177),(.072,.076,.088),.020)
    ellipsoid((0,.291,-.282),(.090,.077,.084),.018)
    for side in [-1,1]:
        ellipsoid((side*.051,.273,-.298),(.044,.045,.057),.011)
    ellipsoid((0,.276,-.339),(.036,.033,.036),.010)
    for side in [-1,1]:ellipsoid((side*.025,.260,-.358),(.030,.023,.032),.007)
    ellipsoid((0,.241,-.348),(.037,.015,.032),.008)
    for side in [-1,1]:
        x=side*.082
        ellipsoid((side*.074,.223,-.133),(.045,.065,.059),.016)
        capsule((x,.218,-.151),(x,.132,-.143),.034,.024)
        capsule((x,.132,-.143),(x,.045,-.177),.024,.018,.010)
        ellipsoid((x,.021,-.212),(.030,.021,.043),.007)
        for toe in [-.018,-.006,.006,.018]:ellipsoid((x+toe,.020,-.245),(.010,.015,.015),.004)
        x=side*.086
        ellipsoid((side*.076,.214,.177),(.055,.075,.073),.018)
        capsule((x,.214,.179),(x,.134,.105),.039,.025)
        capsule((x,.134,.105),(x,.061,.206),.026,.017,.010)
        capsule((x,.061,.206),(x,.027,.156),.018,.015,.008)
        ellipsoid((x,.021,.139),(.029,.020,.041),.007)
        for toe in [-.018,-.006,.006,.018]:ellipsoid((x+toe,.019,.108),(.010,.014,.014),.004)
        # Tapered ears fuse into the skull. Rounded edges, not four-face pyramids.
        t=np.clip((Y-.338)/.080,0,1)
        cx=side*(.060+.020*t);cz=-.285+.009*t
        rx=.032*(1-t)**.72+.0013;rz=.018*(1-t)+.0010
        radial=(np.sqrt(((X-cx)/rx)**2+((Z-cz)/rz)**2)-1)*np.minimum(rx,rz)
        d=np.maximum(radial,np.maximum(.338-Y,Y-.418))
        union(d,.006)
    # Shallow eyelid sockets; retain the forehead and cheek volume.
    for side in [-1,1]:
        d=(np.sqrt(((X-side*.052)/.024)**2+((Y-.309)/.016)**2+((Z+.345)/.013)**2)-1)*.013
        field=np.maximum(field,-d)
    print('Extracting continuous body, grid',shape,flush=True)
    v,f,n=isosurface(field,axes)
    add('Continuous_Anatomy',v,f,n)
    edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1)
    unique,counts=np.unique(edges,axis=0,return_counts=True)
    graph=coo_matrix((np.ones(len(unique)),(unique[:,0],unique[:,1])),shape=(len(v),len(v)))
    components=connected_components(graph,directed=False,return_labels=False)
    return dict(body_vertices=len(v),body_triangles=len(f),body_components=int(components),nonmanifold_edges=int(np.count_nonzero(counts!=2)))

def isosurface(field,axes):
    # Indexed marching tetrahedra: neighboring cells share exactly the same edge vertices.
    corners=np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]])
    slices=[field[x:field.shape[0]-1+x,y:field.shape[1]-1+y,z:field.shape[2]-1+z] for x,y,z in corners]
    signs=np.stack([a<0 for a in slices],axis=-1)
    active=np.any(signs,axis=-1)&~np.all(signs,axis=-1)
    coords=np.column_stack(np.nonzero(active))
    grid=coords[:,None,:]+corners[None,:,:]
    ids=np.ravel_multi_index(grid.transpose(2,0,1),field.shape)
    flat=field.ravel(); values=flat[ids]
    tets=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
    batches=[]
    for tet in tets:
        tid=ids[:,tet];code=np.sum((values[:,tet]<0)*np.array([1,2,4,8]),axis=1)
        for case in range(1,15):
            selected=tid[code==case]
            if not len(selected):continue
            ins=[i for i in range(4) if case&(1<<i)];out=[i for i in range(4) if not case&(1<<i)]
            if len(ins)==1:tri=[[(ins[0],q) for q in out]]
            elif len(ins)==3:tri=[[(out[0],q) for q in ins]]
            else:
                a,b=ins;c,d=out
                tri=[[(a,c),(a,d),(b,d)],[(a,c),(b,d),(b,c)]]
            for t in tri:
                ep=selected[:,np.array(t)].reshape(-1,2)
                batches.append(np.sort(ep,axis=1))
    edges=np.concatenate(batches)
    unique,inverse=np.unique(edges,axis=0,return_inverse=True)
    f=inverse.reshape(-1,3)
    a,b=unique.T;fa,fb=flat[a],flat[b];t=(-fa/(fb-fa))[:,None]
    ia=np.array(np.unravel_index(a,field.shape)).T;ib=np.array(np.unravel_index(b,field.shape)).T
    va=np.column_stack([axes[k][ia[:,k]] for k in range(3)])
    vb=np.column_stack([axes[k][ib[:,k]] for k in range(3)])
    v=va+(vb-va)*t
    grad=np.stack(np.gradient(field,*[float(ax[1]-ax[0]) for ax in axes]),axis=-1).reshape(-1,3)
    n=grad[a]+(grad[b]-grad[a])*t;n/=np.linalg.norm(n,axis=1)[:,None]
    cross=np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]])
    wrong=np.sum(cross*n[f].mean(axis=1),axis=1)<0
    f[wrong]=f[wrong][:,[0,2,1]]
    return v,f,n

def sphere(name,center,radii,material,bind,segments=48,rings=28,color=None,eye=False):
    # UV sphere with shared poles and closed manifold triangles.
    v=[np.array(center)+[0,radii[1],0]];norm=[[0,1,0]];uv=[[.5,0]]
    for r in range(1,rings):
        phi=math.pi*r/rings
        for i in range(segments):
            theta=math.tau*i/segments
            p=np.array([math.sin(phi)*math.cos(theta),math.cos(phi),math.sin(phi)*math.sin(theta)])
            q=p*np.array(radii)
            if eye:q[1]*=1-.22*abs(p[0])
            v.append(np.array(center)+q);norm.append(p/np.array(radii));uv.append([i/segments,r/rings])
    bottom=len(v);v.append(np.array(center)-[0,radii[1],0]);norm.append([0,-1,0]);uv.append([.5,1])
    f=[]
    for i in range(segments):f.append([0,1+i,1+(i+1)%segments])
    for r in range(rings-2):
        for i in range(segments):
            a=1+r*segments+i;b=1+r*segments+(i+1)%segments;c=a+segments;d=b+segments
            f.extend([[a,c,b],[b,c,d]])
    for i in range(segments):f.append([bottom,bottom-1-i,bottom-1-(i+1)%segments])
    v=np.array(v);n=np.array(norm);n/=np.linalg.norm(n,axis=1)[:,None];f=np.array(f)
    cross=np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]])
    wrong=np.sum(cross*n[f].mean(axis=1),axis=1)<0;f[wrong]=f[wrong][:,[0,2,1]]
    colors=None if color is None else np.tile(list(color)+[1],(len(v),1)).astype('f4')
    add(name,v,f,n,material,bind=bind,colors=colors,uv=np.array(uv,dtype='f4'))

def tube(name,points,radius,material='coat',bind=None,tail=False,sides=24):
    points=np.asarray(points);tangent=np.gradient(points,axis=0);tangent/=np.linalg.norm(tangent,axis=1)[:,None]
    frame=np.cross(tangent,np.array([1,0,0]));frame/=np.linalg.norm(frame,axis=1)[:,None]
    other=np.cross(tangent,frame);angles=np.arange(sides)*math.tau/sides
    radial=frame[:,None,:]*np.cos(angles)[None,:,None]+other[:,None,:]*np.sin(angles)[None,:,None]
    radii=np.broadcast_to(radius,(len(points),))
    v=(points[:,None,:]+radial*radii[:,None,None]).reshape(-1,3);n=radial.reshape(-1,3)
    f=[]
    for row in range(len(points)-1):
        for j in range(sides):
            a=row*sides+j;b=row*sides+(j+1)%sides;c=a+sides;d=b+sides
            f.extend([[a,c,b],[b,c,d]])
    # Two closed caps.
    for j in range(1,sides-1):f.extend([[0,j+1,j],[(len(points)-1)*sides,(len(points)-1)*sides+j,(len(points)-1)*sides+j+1]])
    colors=None
    if tail:
        ts=np.repeat(np.linspace(0,1,len(points)),sides)
        colors=np.tile(np.r_[ORANGE,1],(len(v),1))
        colors[(ts<.15)|(ts>.56)&(ts<.82)]=np.r_[BLACK,1]
        colors[ts>.84]=np.r_[CREAM,1]
    add(name,v,np.array(f),n,material,'tail' if tail else 'body',bind,colors)

def details():
    for side in [-1,1]:
        head=IDX['head'];x=side*.052
        # Almond lids inset into the carved sockets, subdued amber-green irises.
        sphere('Eyelids',(x,.309,-.334),(.0245,.0155,.012),'lid',head,48,24)
        sphere('Eye',(x,.309,-.341),(.022,.0125,.007),'eye',head,56,32,eye=True)
        sphere('Iris',(x,.309,-.347),(.0095,.0105,.003),'iris',head,48,28)
        sphere('Pupil',(x,.309,-.350),(.0025,.0092,.0012),'pupil',head,32,24)
        # A tiny corneal glint rather than detached white eyeballs.
        sphere('Glint',(x-.0037,.312,-.351),(.0016,.0020,.0009),'glint',head,20,16)
        # Inner ear triangle follows the tapered shell and blends at its base.
        A=np.array([side*.038,.354,-.303]);B=np.array([side*.086,.352,-.301]);C=np.array([side*.078,.407,-.280])
        v=[];n=[];f=[];lookup={};steps=22
        for i in range(steps+1):
            for j in range(steps+1-i):
                u=i/steps;w=j/steps;p=A*(1-u-w)+B*u+C*w
                t=np.clip((p[1]-.338)/.080,0,1)
                cx=side*(.060+.020*t);cz=-.285+.009*t
                rx=.032*(1-t)**.72+.0013;rz=.018*(1-t)+.0010
                p[2]=cz-rz*math.sqrt(max(0,1-((p[0]-cx)/rx)**2))-.0005
                lookup[i,j]=len(v);v.append(p);n.append([0,0,-1])
        for i in range(steps):
            for j in range(steps-i):
                f.append([lookup[i,j],lookup[i+1,j],lookup[i,j+1]])
                if j<steps-i-1:f.append([lookup[i+1,j],lookup[i+1,j+1],lookup[i,j+1]])
        add('InnerEar',np.array(v),np.array(f),np.array(n),'inner_ear',bind=IDX['ear_L' if side<0 else 'ear_R'])
        for k in range(6):
            a=np.array([side*.026,.255+(k%3)*.004,-.383])
            b=np.array([side*(.115+k*.008),.246+(k-2.5)*.010,-.346+k*.005])
            ts=np.linspace(0,1,15)
            p=a[None,:]*(1-ts[:,None])+b[None,:]*ts[:,None]
            p[:,1]+=.003*np.sin(ts*math.pi)
            tube('Whisker',p,np.linspace(.00042,.00012,len(ts)),'whisker',head,sides=7)
        for pre,z in [('front',-.251),('rear',.101)]:
            x=side*(.082 if pre=='front' else .086)
            bind=IDX[f'{pre}_toes_{"L" if side<0 else "R"}']
            for dx in [-.017,-.005,.007,.018]:
                sphere('RetractedClaw',(x+dx,.017,z),(.0014,.0018,.003),'claw',bind,12,10)
    sphere('Nose',(0,.272,-.389),(.0135,.008,.010),'nose',IDX['head'],48,24)
    jaw=IDX['jaw']
    tube('Philtrum',[[0,.266,-.396],[0,.256,-.388],[0,.251,-.380]],.00065,'mouth',jaw,sides=8)
    for side in [-1,1]:tube('Lip',[[0,.251,-.380],[side*.010,.247,-.377],[side*.021,.248,-.370]],.00055,'mouth',jaw,sides=8)
    p=curve(np.linspace(0,1,160));r=.017*(1-np.linspace(0,1,160))**.7+.002
    tube('ContinuousCurledTail',p,r,tail=True,sides=40)

def write_model(stats):
    blob=bytearray();surfaces=[]
    def write(array,dtype):
        data=np.asarray(array,dtype=dtype).tobytes();offset=len(blob);blob.extend(data)
        return [offset,len(data)]
    for mat,parts in PARTS.items():
        offsets=np.cumsum([0]+[len(p['v']) for p in parts[:-1]])
        merged={key:np.concatenate([p[key] for p in parts]) for key in ['v','n','j','w','c','uv']}
        f=np.concatenate([p['f']+offset for p,offset in zip(parts,offsets)])
        cross=np.cross(merged['v'][f[:,1]]-merged['v'][f[:,0]],merged['v'][f[:,2]]-merged['v'][f[:,0]])
        wrong=np.sum(cross*merged['n'][f].mean(axis=1),axis=1)<0
        f[wrong]=f[wrong][:,[0,2,1]]
        # Godot uses clockwise front faces.
        surfaces.append(dict(name=mat,vertices=len(merged['v']),indices=f.size,
            positions=write(merged['v'],'<f4'),normals=write(merged['n'],'<f4'),uv=write(merged['uv'],'<f4'),
            colors=write(merged['c'],'<f4'),joints=write(merged['j'],'<i4'),weights=write(merged['w'],'<f4'),indices_data=write(f[:,[0,2,1]],'<i4')))
    stats.update(vertices=sum(s['vertices'] for s in surfaces),triangles=sum(s['indices']//3 for s in surfaces),bones=len(BONES),surfaces=len(surfaces),reference='arched back, integrated shoulders, folded hind legs, rounded paws, continuous curled tail')
    stats['source_weight_error']=max(float(np.max(np.abs(p['w'].astype('f8').sum(axis=1)-1))) for parts in PARTS.values() for p in parts)
    assert stats['source_weight_error']<5e-7, 'Source weights must sum to one'
    data=dict(version=2,bones=BONES,legs=LEGS,tail_bones=tail_ids,surfaces=surfaces,stats=stats)
    (OUT/'calico_anatomy.bin').write_bytes(blob)
    (OUT/'calico_anatomy.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
    (OUT/'model_report.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
    assert stats['body_components']==1, 'Body must be one connected surface'
    assert stats['nonmanifold_edges']==0, 'Body must be closed and manifold'
    assert stats['triangles']>104532, 'New model must have at least twice the original face count'
    print(json.dumps(stats,indent=2),flush=True)

if __name__=='__main__':
    stats=organic_body();details();write_model(stats)
