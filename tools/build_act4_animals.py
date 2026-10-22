"""Blender: seamless, metre-scale rodents and a compatible kitchen resting pose.
Keeps the existing dog's skin, topology, materials and landing animation untouched.
"""
import bpy, math, json, sys, struct
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'furniture_pack/quest_props'
AUTHOR = ROOT/'furniture_pack/authoring'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0

def material(name, color, fur=False):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.88 if fur else .48
    if fur:
        t=m.node_tree.nodes.new('ShaderNodeTexImage')
        t.image=bpy.data.images.load(str(ROOT/'act4/textures/rodent_fur.png'),check_existing=True)
        uv=m.node_tree.nodes.new('ShaderNodeTexCoord');mapping=m.node_tree.nodes.new('ShaderNodeMapping')
        mapping.inputs['Scale'].default_value=(4,4,4)
        m.node_tree.links.new(uv.outputs['UV'],mapping.inputs['Vector']);m.node_tree.links.new(mapping.outputs['Vector'],t.inputs['Vector'])
        ramp=m.node_tree.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color=(*(c*.5 for c in color),1)
        ramp.color_ramp.elements[1].color=(*(min(1,c*1.45) for c in color),1)
        m.node_tree.links.new(t.outputs['Color'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],p.inputs['Base Color'])
    return m

def xyz(p):return (p[0],-p[2],p[1])
def ell(name,p,s,mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=.5,location=xyz(p))
    o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons:f.use_smooth=True
    if mat:o.data.materials.append(mat)
    return o

def tube(name,points,radii,mat,sides=10):
    verts=[];faces=[];points=[Vector(xyz(p)) for p in points]
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        q=tangent.to_track_quat('Z','Y')
        for j in range(sides):verts.append(p+q@Vector((math.cos(j*math.tau/sides)*radii[i],math.sin(j*math.tau/sides)*radii[i],0)))
    for i in range(len(points)-1):
        for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
    for f in mesh.polygons:f.use_smooth=True
    return o

def union(parts,name,mat,voxel):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=parts[0];o.name=name
    rem=o.modifiers.new('Continuous anatomical surface','REMESH');rem.mode='VOXEL';rem.voxel_size=voxel
    bpy.ops.object.modifier_apply(modifier=rem.name)
    smooth=o.modifiers.new('Relax silhouette','SMOOTH');smooth.factor=.65;smooth.iterations=4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    sub=o.modifiers.new('Smooth game topology','SUBSURF');sub.levels=1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    tri_count=sum(len(p.vertices)-2 for p in o.data.polygons)
    dec=o.modifiers.new('Realtime budget','DECIMATE');dec.ratio=min(.9,14000/max(1,tri_count))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    o.data.materials.clear();o.data.materials.append(mat)
    for f in o.data.polygons:f.use_smooth=True
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
    return o

for mole in ([] if '--dog-only' in sys.argv else [True,False]):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    fur=material('Velvet brown fur' if mole else 'Warm grey short fur',(.29,.22,.16) if mole else (.58,.55,.49),True)
    skin=material('Soft nose and pads',(.52,.29,.25));claw=material('Ivory claws',(.70,.64,.48))
    eye=material('Moist dark eye',(.012,.015,.014));glint=material('Eye glint',(.8,.81,.75))
    if mole:
        parts=[ell('Chest',(0,.045,.018),(.125,.22,.12)),ell('Shoulders',(0,.108,-.007),(.145,.13,.13)),ell('Head',(0,.153,-.044),(.111,.102,.117)),ell('Muzzle',(0,.14,-.107),(.056,.043,.09))]
    else:
        parts=[ell('Haunch',(0,.047,.035),(.09,.083,.125)),ell('Torso',(0,.054,-.009),(.075,.08,.125)),ell('Neck',(0,.064,-.063),(.056,.063,.066)),ell('Head',(0,.072,-.088),(.064,.065,.079)),ell('Muzzle',(0,.056,-.128),(.035,.029,.058))]
        for side in [-1,1]:
            parts.extend([ell('Forelimb',(side*.032,.034,-.050),(.023,.065,.029)),ell('HaunchLeg',(side*.037,.032,.050),(.034,.059,.045))])
    body=union(parts,'ContinuousFurredBody',fur,.0019 if mole else .0012)
    # Bake the remapped fine fur into this mesh's own UV; glTF receives ordinary
    # Base Color textures rather than unsupported procedural shader nodes.
    image=bpy.data.images.new('MoleFineCoat' if mole else 'MouseFineCoat',width=1024,height=1024)
    target=fur.node_tree.nodes.new('ShaderNodeTexImage');target.image=image;fur.node_tree.nodes.active=target
    bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
    bpy.context.scene.render.bake.use_pass_direct=False;bpy.context.scene.render.bake.use_pass_indirect=False
    bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
    bpy.ops.object.bake(type='DIFFUSE',pass_filter={'COLOR'},margin=8)
    baked=material('Baked fine coat',(.5,.5,.5));baked.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.95
    tx=baked.node_tree.nodes.new('ShaderNodeTexImage');tx.image=image
    baked.node_tree.links.new(tx.outputs['Color'],baked.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    body.data.materials.clear();body.data.materials.append(baked)
    # Small ear/arm meshes use the same quiet fur tone, without stretched stripes.
    fur=material('Short fur details',(.29,.22,.16) if mole else (.58,.55,.49))
    nose=(0,.139,-.149) if mole else (0,.056,-.153)
    ell('PinkSensitiveNose',nose,(.021,.015,.013) if mole else (.012,.010,.009),skin)
    for side in [-1,1]:
        ep=(side*.044,.169,-.076) if mole else (side*.027,.085,-.108)
        ell('DarkEye',ep,(.006,.006,.005) if mole else (.009,.010,.006),eye)
        ell('EyeCatchlight',(ep[0],ep[1]+.002,ep[2]-.003),(.0018,.0018,.0015),glint)
        if not mole:
            ear=ell('OuterEar',(side*.034,.108,-.070),(.035,.044,.012),fur);ear.rotation_euler.y=side*.16
            ell('RecessedPinkEar',(side*.034,.109,-.077),(.026,.032,.004),skin)
        for i in range(4):
            a=(side*.012,nose[1]+.002,nose[2]+.012)
            tube('TaperedWhisker',[a,(side*.040,nose[1]+.005+i*.003,nose[2]+.015),(side*.071,nose[1]-.006+i*.007,nose[2]+.035+i*.006)],[.0005,.00035,.00008],claw,6)
        if mole:
            arm=ell('ShoulderArm',(side*.082,.075,-.025),(.060,.090,.070),fur)
            palm=ell('BroadDiggingPalm',(side*.106,.054,-.072),(.070,.030,.060),skin)
            for i in range(5):
                x=side*(.082+i*.011)
                tube('DiggingFinger',[(x,.053,-.084),(x+side*.003,.048,-.107)],[.0042,.0034],skin)
                tube('StrongCurvedClaw',[(x+side*.003,.049,-.105),(x+side*.005,.046,-.123),(x+side*.005,.040,-.131)],[.0034,.0020,.0003],claw)
        else:
            for front in [True,False]:
                x=side*(.034 if front else .043);z=-.056 if front else .055
                paw=ell(('ForePaw' if front else 'HindPaw')+('L' if side<0 else 'R'),(x,.013,z),(.021,.015,.033),skin)
                for toe in range(4):tube('PawToe',[(x+(toe-1.5)*.004,.012,z-.010),(x+(toe-1.5)*.005,.009,z-.027)],[.0017,.0010],skin,8)
    if not mole:
        points=[(math.sin(i*.11)*.045,.010+math.sin(i*.13)*.004,.082+i*.008) for i in range(26)]
        tail=tube('TaperedTail',points,[.005*(1-i/28) for i in range(26)],skin,12)
        for i in range(2,23,2):
            p=points[i];ell('TailFineRing',p,(.010*(1-i/28),.009*(1-i/28),.0012),skin)
    else:
        # Lower torso continues below the hole plane; never a floating head.
        ell('BuriedLowerBody',(0,-.042,.028),(.115,.10,.10),fur)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/('mole_upper_body.blend' if mole else 'house_mouse.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/('mole_upper_body.glb' if mole else 'house_mouse.glb')),export_format='GLB',export_animations=False,export_yup=True)

# Pose the original weighted dog without rewriting its mesh or its original clip.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/pets/landing_dog.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');arm.animation_data_clear()
for p in arm.pose.bones:p.matrix_basis.identity()
bpy.context.view_layer.update()
C=Matrix.Rotation(-math.pi/2,4,'X')
def local_rows():
    rows={}
    for b in arm.pose.bones:
        local=b.parent.matrix.inverted()@b.matrix if b.parent else b.matrix
        m=C@local@C.inverted();q=m.to_quaternion();p=m.translation
        rows[b.name]={'position':list(p),'rotation':[q.x,q.y,q.z,q.w]}
    return rows
neutral=local_rows()
def bone(token):return next(b for b in arm.pose.bones if token in b.name)
root=bone('ROOT');root.matrix=Matrix.Translation((0,0,-.40))@root.bone.matrix_local
bpy.context.view_layer.update()
for token,angle in [('Neck_01',-.85),('Neck_02',-.18)]:
    b=bone(token);rest=b.bone.matrix_local.to_quaternion()
    b.rotation_mode='QUATERNION';b.rotation_quaternion=rest.inverted()@Quaternion((1,0,0),angle)@rest
    bpy.context.view_layer.update()
top=bone('Neck_Top');m=top.bone.matrix_local.copy();m.translation=top.head.copy();top.matrix=m
bpy.context.view_layer.update()
def pair(a,t,l1,l2,pole):
    d=max(abs(l1-l2)+.0001,min((t-a).length,l1+l2-.0001));axis=(t-a).normalized()
    p=(pole-axis*pole.dot(axis)).normalized();along=(l1*l1-l2*l2+d*d)/(2*d)
    return a+axis*along+p*math.sqrt(max(0,l1*l1-along*along)),a+axis*d
for front in [True,False]:
    for side,s in [('l',-1),('r',1)]:
        tokens=['Hip','Knee','Ankle','Ball','Toe'] if front else ['Hip','Knee1','Knee2','Ankle','Ball','Toe']
        names=[bone(side+('_FrontLeg_' if front else '_HindLeg_')+t).name for t in tokens]
        rest=[arm.data.bones[n].head_local.copy() for n in names];initial=[arm.pose.bones[n].matrix.copy() for n in names]
        points=[m.translation.copy() for m in initial];hip=points[0]
        lengths=[(b-a).length for a,b in zip(rest,rest[1:])]
        ankle=Vector((s*(.115 if front else .17),.56 if front else -.30,.070 if front else .078))
        if front:
            knee,end=pair(hip,ankle,lengths[0],lengths[1],Vector((s*.1,-1,.1)));solved=[hip,knee,end]
        else:
            first=hip+Vector((s*.22,.78,-.62)).normalized()*lengths[0]
            knee,end=pair(first,ankle,lengths[1],lengths[2],Vector((s*.4,-1,-.2)));solved=[hip,first,knee,end]
        if front:
            ball=solved[-1]+Vector((0,1,-.36)).normalized()*lengths[2]
            toe=ball+Vector((0,1,-.06)).normalized()*lengths[3]
            solved.extend([ball,toe])
        else:solved.extend([solved[-1]+rest[-2]-rest[-3],solved[-1]+rest[-1]-rest[-3]])
        for i in range(len(solved)-1):
            q=(points[i+1]-points[i]).normalized().rotation_difference((solved[i+1]-solved[i]).normalized())@initial[i].to_quaternion()
            m=q.to_matrix().to_4x4();m.translation=solved[i];arm.pose.bones[names[i]].matrix=m;bpy.context.view_layer.update()
        m=initial[-1].copy();m.translation=solved[-1];arm.pose.bones[names[-1]].matrix=m;bpy.context.view_layer.update()
pose=local_rows()
(ROOT/'assets/models/pets/kitchen_rest_pose.json').write_text(json.dumps({'units':'metres','reference_rest':neutral,'pose':pose},indent=2))
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/models/pets/authoring/dog_kitchen_rest.blend'))
catalog_path=OUT/'catalog.json'
catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
for name,title in [('mole_upper_body','完整上半身地鼠：肩胸、鼻吻与五指掘土爪'),('house_mouse','短毛家鼠：连续躯干、耳廓、四肢、尖吻与渐细长尾')]:
    data=(OUT/(name+'.glb')).read_bytes();gltf=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
    tris=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
    catalog=[row for row in catalog if row['id']!=name]+[{'id':name,'name':title,'triangles':tris,'materials':len(gltf['materials']),'units':'metres','source':'tools/build_act4_animals.py'}]
catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('ACT4_ANIMALS_AND_DOG_POSE_CREATED')
