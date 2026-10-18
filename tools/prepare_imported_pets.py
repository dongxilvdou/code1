"""Run with Blender --background --python. Metres, Blender +Y facing / Godot -Z.
Preserves the supplied animal topology, UVs, materials and weighted armatures.
Adds named, baked skeletal clips and a matching skinned first-person foreleg mesh.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/pets'
AUTHOR=OUT/'authoring'
OUT.mkdir(parents=True,exist_ok=True)
AUTHOR.mkdir(exist_ok=True)
(AUTHOR/'.gdignore').write_text('')
REPORT=json.loads((OUT/'pet_assets.json').read_text()) if (OUT/'pet_assets.json').exists() else {}
TAU=math.tau

def findbone(arm, token):
 return next(b.name for b in arm.data.bones if token in b.name)

def smooth_cat_joints(mesh):
 # Keep face, ears and tail weights intact. Soften only anatomical body/limb
 # boundaries, including duplicated UV-seam vertices at the same position.
 names={g.index:g.name for g in mesh.vertex_groups}
 editable={i for i,n in names.items() if any(t in n for t in ('Spine_','FrontLeg_','HindLeg_'))}
 weights=[{g.group:g.weight for g in v.groups} for v in mesh.data.vertices]
 eligible=[sum(w for g,w in row.items() if g in editable)>.97 for row in weights]
 adjacency=[set() for _ in weights]
 for e in mesh.data.edges:
  a,b=e.vertices;adjacency[a].add(b);adjacency[b].add(a)
 seams={}
 for v in mesh.data.vertices:seams.setdefault(tuple(round(c,5) for c in v.co),[]).append(v.index)
 for group in seams.values():
  if len(group)>1:
   for i in group:adjacency[i].update(j for j in group if j!=i)
 for _ in range(5):
  updated=[]
  for i,row in enumerate(weights):
   neighbors=[j for j in adjacency[i] if eligible[j]]
   if not eligible[i] or not neighbors:updated.append(row);continue
   out={g:w*.65 for g,w in row.items()}
   for j in neighbors:
    for g,w in weights[j].items():out[g]=out.get(g,0)+w*.35/len(neighbors)
   out=dict(sorted(out.items(),key=lambda x:x[1],reverse=True)[:4]);total=sum(out.values())
   updated.append({g:w/total for g,w in out.items()})
  weights=updated
 for i,row in enumerate(weights):
  if not eligible[i]:continue
  for group_id in [g.group for g in mesh.data.vertices[i].groups]:mesh.vertex_groups[group_id].remove([i])
  for g,w in row.items():mesh.vertex_groups[g].add([i],w,'REPLACE')

def setup(kind):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 source=Path('C:/zGoDot/3D')/('cat/bicolor-cat/source/bicolor Cat.glb' if kind=='cat' else 'dog/dog-puppy/source/dog puppy.glb')
 bpy.ops.import_scene.gltf(filepath=str(source))
 arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 arm.animation_data_clear()
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 for p in arm.pose.bones:p.matrix_basis.identity()
 bpy.context.view_layer.update()
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and (any(m.type=='ARMATURE' for m in o.modifiers) or o.name=='hair')]
 shoulder=(arm.matrix_world@arm.data.bones[findbone(arm,'Spine_Top')].head_local).z
 scale=(.32 if kind=='cat' else .64)/shoulder
 transform=Matrix.Scale(scale,4)@Matrix.Rotation(math.pi,4,'Z')
 # Capture bone-parented whisker geometry at the rest pose before unparenting.
 mesh_transforms={o.name:transform@o.matrix_world for o in meshes}
 arm.data.transform(transform@arm.matrix_world)
 arm.matrix_world=Matrix.Identity(4)
 arm.name='HouseCatRig' if kind=='cat' else 'LandingDogRig'
 for o in meshes:
  had_arm=any(m.type=='ARMATURE' for m in o.modifiers)
  o.parent=None
  o.data.transform(mesh_transforms[o.name],shape_keys=True)
  if o.name=='hair':
   # The supplied whisker object has an offset bone-parent transform. Seat
   # its original mesh on the muzzle instead of leaving it floating in front.
   points=[v.co for v in o.data.vertices]
   centre=Vector((sum(p.x for p in points)/len(points),sum(p.y for p in points)/len(points),sum(p.z for p in points)/len(points)))
   o.data.transform(Matrix.Translation(Vector((0,.405,.395))-centre))
  o.matrix_world=Matrix.Identity(4)
  o.parent=arm
  if not had_arm:
   vg=o.vertex_groups.new(name=findbone(arm,'Neck_Top'))
   vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
   o.modifiers.new('HeadAttachment','ARMATURE').object=arm
  for m in o.modifiers:
   if m.type=='ARMATURE':m.object=arm
  for poly in o.data.polygons:poly.use_smooth=True
  if kind=='cat' and o.name!='hair':smooth_cat_joints(o)
  for mat in o.data.materials:
   if mat and mat.use_nodes:
    for node in mat.node_tree.nodes:
     if node.type=='BSDF_PRINCIPLED':
      node.inputs['Metallic'].default_value=0
      node.inputs['Roughness'].default_value=.83
 for o in list(bpy.context.scene.objects):
  if o!=arm and o not in meshes:bpy.data.objects.remove(o,do_unlink=True)
 for p in arm.pose.bones:p.matrix_basis.identity()
 bpy.context.view_layer.update()
 return arm,meshes

def rotate(arm,name,axis,angle):
 p=arm.pose.bones[name]
 rest=p.bone.matrix_local.to_quaternion()
 p.rotation_mode='QUATERNION'
 p.rotation_quaternion=rest.inverted()@Quaternion(axis,angle)@rest

def legs_for(arm):
 legs=[]
 for front in (True,False):
  for side in ('l','r'):
   prefix=side+('_FrontLeg_' if front else '_HindLeg_')
   parts=['Hip','Knee','Ankle','Ball','Toe'] if front else ['Hip','Knee1','Knee2','Ankle','Ball','Toe']
   names=[findbone(arm,prefix+part) for part in parts]
   legs.append({'front':front,'names':names,'points':[arm.data.bones[n].head_local.copy() for n in names]})
 return legs

def bent_pair(a,target,l1,l2,pole):
 """Analytic two-link fold; lengths never change and the bend plane is stable."""
 delta=target-a
 d=max(abs(l1-l2)+.0001,min(delta.length,l1+l2-.0001))
 axis=delta.normalized()
 bend=pole-axis*pole.dot(axis)
 if bend.length<.001:bend=axis.cross(Vector((0,0,1)))
 bend.normalize()
 along=(l1*l1-l2*l2+d*d)/(2*d)
 return a+axis*along+bend*math.sqrt(max(0,l1*l1-along*along)),a+axis*d

def sleeping_legs(arm,legs):
 # Solve in the already curved torso pose. Transport the original bone rolls
 # with a swing quaternion instead of re-imposing rest rotations on bent limbs.
 for leg in legs:
  names=leg['names']; front=leg['front']; rest=leg['points']
  initial=[arm.pose.bones[n].matrix.copy() for n in names]
  points=[m.translation.copy() for m in initial]
  hip=points[0]
  yaw=initial[0].to_quaternion()@arm.data.bones[names[0]].matrix_local.to_quaternion().inverted()
  foot=hip+yaw@Vector((0,.16 if front else .18,0))
  foot.z=.038
  offset=yaw@(rest[-2]-rest[-3])
  target=foot-offset
  lengths=[(b-a).length for a,b in zip(rest,rest[1:])]
  if front:
   side=1 if hip.x>-.1 else -1
   knee,ankle=bent_pair(hip,target,lengths[0],lengths[1],yaw@Vector((side*.8,-1,.25)))
   solved=[hip,knee,ankle]
  else:
   side=1 if hip.x>0 else -1
   first=hip+(yaw@Vector((side*.15,.58,-.8))).normalized()*lengths[0]
   knee,ankle=bent_pair(first,target,lengths[1],lengths[2],yaw@Vector((side,0,-.25)))
   solved=[hip,first,knee,ankle]
  for i in range(len(solved)-1):
   old_direction=(points[i+1]-points[i]).normalized()
   new_direction=(solved[i+1]-solved[i]).normalized()
   q=old_direction.rotation_difference(new_direction)@initial[i].to_quaternion()
   m=q.to_matrix().to_4x4();m.translation=solved[i]
   arm.pose.bones[names[i]].matrix=m
   bpy.context.view_layer.update()
  for i in range(len(names)-3,len(names)):
   m=initial[i].copy()
   m.translation=solved[-1]+yaw@(rest[i]-rest[-3])
   arm.pose.bones[names[i]].matrix=m
   bpy.context.view_layer.update()

def cat_legs(arm,legs,state,u):
 """Fixed-length limbs with stable elbow/hock planes and transported rolls."""
 for i,leg in enumerate(legs):
  front=leg['front'];names=leg['names'];rest=leg['points']
  initial=[arm.pose.bones[n].matrix.copy() for n in names]
  points=[m.translation.copy() for m in initial]
  hip=points[0]
  carried=initial[0].to_quaternion()@arm.data.bones[names[0]].matrix_local.to_quaternion().inverted()
  target=rest[-2].copy();target.z=max(.002,target.z)
  if state in ('walk','run','crouch'):
   run=state=='run';cycle=(u+([0,.08,.48,.56][i] if run else [0,.5,.75,.25][i]))%1
   duty=.45 if run else .64;reach=.095 if run else .065 if state=='walk' else .045
   if cycle<duty:target.y+=(1-2*cycle/duty)*reach
   else:
    t=(cycle-duty)/(1-duty);target.y+=(-1+2*t)*reach
    target.z+=math.sin(t*math.pi)*(.060 if run else .037)
  if state=='jump':
   tuck=math.sin(u*math.pi)**.8;target.z+=(.075 if front else .09)*tuck
   target.y+=(.035 if front else -.025)*tuck
  if state=='stretch':target.y+=(.028 if front else -.010)*math.sin(u*math.pi)**.65
  if state=='sit':target.y+=.01 if front else -.02
  ankle_target=target-carried@(rest[-2]-rest[-3])
  lengths=[(b-a).length for a,b in zip(rest,rest[1:])]
  if front:
   knee,ankle=bent_pair(hip,ankle_target,lengths[0],lengths[1],carried@Vector((0,-1,0)))
   solved=[hip,knee,ankle]
  else:
   flex=.45 if state=='crouch' else .85 if state=='sit' else .0
   first=hip+carried@(Quaternion((1,0,0),flex)@(rest[1]-rest[0]))
   hock,ankle=bent_pair(first,ankle_target,lengths[1],lengths[2],carried@Vector((0,-1,0)))
   solved=[hip,first,hock,ankle]
  for j in range(len(solved)-1):
   q=(points[j+1]-points[j]).normalized().rotation_difference((solved[j+1]-solved[j]).normalized())@initial[j].to_quaternion()
   m=q.to_matrix().to_4x4();m.translation=solved[j]
   arm.pose.bones[names[j]].matrix=m;bpy.context.view_layer.update()
  # Use the achieved ankle, including reach clamping. Never force a distal
  # joint beyond the upper limb's solution to manufacture a longer stride.
  for j in range(len(names)-3,len(names)):
   m=initial[j].copy();m.translation=solved[-1]+carried@(rest[j]-rest[-3])
   arm.pose.bones[names[j]].matrix=m;bpy.context.view_layer.update()

def pose(arm,legs,kind,state,u):
 for p in arm.pose.bones:p.matrix_basis.identity()
 bpy.context.view_layer.update()
 move=state in ('walk','run','crouch')
 run=state=='run'
 sleep=state=='sleep'
 # Constant-pose holds transition through the runtime AnimationPlayer crossfade.
 root=findbone(arm,'ROOT')
 lower=.060 if state=='crouch' else .090 if state=='sit' else .38 if sleep else .035 if run else .022 if move else .014*math.sin(u*math.pi)**.65 if state=='stretch' else .0
 lower*=2 if kind=='dog' and not sleep else 1
 breath=math.sin(u*TAU)*(.002 if kind=='cat' else .004)
 arm.pose.bones[root].matrix=Matrix.Translation((0,0,-lower+breath))@arm.data.bones[root].matrix_local
 if move:
  rotate(arm,findbone(arm,'Spine_03'),(0,1,0),math.sin(u*TAU)*.025)
 if state=='stretch':
  stretch=math.sin(u*math.pi)**.65
  rotate(arm,findbone(arm,'Spine_Top'),(1,0,0),-.10*stretch)
  rotate(arm,findbone(arm,'Neck_01'),(1,0,0),-.14*stretch)
 if state=='sit':
  for token,angle in [('Spine_01',.08),('Spine_02',.05),('Spine_03',.05),('Spine_04',.04)]:rotate(arm,findbone(arm,token),(1,0,0),angle)
  rotate(arm,findbone(arm,'Neck_01'),(1,0,0),-.22)
 if sleep:
  for token,angle in [('Spine_01',.04),('Spine_02',.08),('Spine_03',.10),('Spine_04',.08),('Spine_Top',.06)]:
   rotate(arm,findbone(arm,token),(0,0,1),angle)
  rotate(arm,findbone(arm,'Neck_01'),(1,0,0),-1.15)
  rotate(arm,findbone(arm,'Neck_02'),(0,0,1),.42)
  p=arm.pose.bones[findbone(arm,'Neck_02')]
  rest=p.bone.matrix_local.to_quaternion()
  p.rotation_quaternion=rest.inverted()@Quaternion((0,0,1),.42)@Quaternion((1,0,0),-.45)@rest
  bpy.context.view_layer.update()
  top=arm.pose.bones[findbone(arm,'Neck_Top')]
  # The neck lowers the skull, but the muzzle rests forward instead of diving
  # nose-first into the cushion. Keep the skull's original anatomical roll.
  m=(Quaternion((0,0,1),1.15)@Quaternion((1,0,0),-.16)@top.bone.matrix_local.to_quaternion()).to_matrix().to_4x4()
  m.translation=top.head.copy();top.matrix=m
 if state=='meow':rotate(arm,findbone(arm,'Head_Jaw'),(1,0,0),.22*math.sin(u*math.pi)**2)
 for i,b in enumerate(b for b in arm.data.bones if 'Tail_' in b.name):
  rotate(arm,b.name,(0,0,1),(.15 if state=='tailwag' else .025)*math.sin(u*TAU-i*.55))
  if sleep:rotate(arm,b.name,(0,0,1),.36+.004*math.sin(u*TAU))
 bpy.context.view_layer.update()
 if sleep:
  sleeping_legs(arm,legs)
  return
 if kind=='cat':
  cat_legs(arm,legs,state,u)
  return

def export(path,objects,animations=True):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
  export_animations=animations,export_animation_mode='ACTIONS',export_force_sampling=True,
  export_frame_range=False,export_materials='EXPORT',export_yup=True)

if '--kind' not in sys.argv:raise RuntimeError('Pass -- --kind cat or -- --kind dog; run each in its own Blender process.')
for kind in [sys.argv[sys.argv.index('--kind')+1]]:
 arm,meshes=setup(kind)
 legs=legs_for(arm)
 bpy.context.scene.render.fps=30
 actions={}
 states={'idle':3.2,'walk':.72,'run':.5,'crouch':1.0,'jump':.8,'stretch':2.8,'sit':3.2,'tailwag':3.2,'meow':.65} if kind=='cat' else {'sleep':4.0}
 for state,duration in states.items():
  action=bpy.data.actions.new(state)
  action.use_fake_user=True
  arm.animation_data_create()
  arm.animation_data.action=action
  frames=round(duration*30)
  for frame in range(frames+1):
   bpy.context.scene.frame_set(frame)
   pose(arm,legs,kind,state,frame/frames)
   for p in arm.pose.bones:
    p.rotation_mode='QUATERNION'
    # Setting .matrix writes quaternion channels when in quaternion mode.
    p.keyframe_insert('location',frame=frame,group=p.name)
    p.keyframe_insert('rotation_quaternion',frame=frame,group=p.name)
    p.keyframe_insert('scale',frame=frame,group=p.name)
  actions[state]=action
 arm.animation_data.action=actions['idle' if kind=='cat' else 'sleep']
 bpy.context.scene.frame_set(0)
 bpy.context.view_layer.update()
 # Editable native authoring file, with embedded original texture images.
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.file.pack_all()
 for area in bpy.context.screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active
   space.shading.type='MATERIAL'
   space.region_3d.view_location=Vector((0,0,.25))
   space.region_3d.view_distance=1.25 if kind=='cat' else 1.7
   space.region_3d.view_rotation=Vector((-.8,-1.0,-.45)).to_track_quat('-Z','Y')
 for o in bpy.context.selected_objects:o.select_set(False)
 meshes[-1].select_set(True)
 bpy.context.view_layer.objects.active=meshes[-1]
 bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/(kind+'.blend')))
 export(OUT/('house_cat.glb' if kind=='cat' else 'landing_dog.glb'),[arm]+meshes)
 if kind=='cat':
  paws=[]
  front_names={b.name for b in arm.data.bones if 'FrontLeg_' in b.name and any(s in b.name for s in ['Knee','Ankle','Ball','Toe'])}
  for mesh in meshes:
   if not any(m.type=='ARMATURE' for m in mesh.modifiers):continue
   o=mesh.copy();o.data=mesh.data.copy();bpy.context.collection.objects.link(o)
   o.shape_key_clear()
   group_ids={g.index for g in o.vertex_groups if g.name in front_names}
   bm=bmesh.new();bm.from_mesh(o.data)
   deform=bm.verts.layers.deform.active
   remove=[v for v in bm.verts if not deform or sum(w for g,w in v[deform].items() if g in group_ids)<.72]
   bmesh.ops.delete(bm,geom=remove,context='VERTS')
   bm.to_mesh(o.data);bm.free()
   if len(o.data.polygons):paws.append(o)
   else:bpy.data.objects.remove(o,do_unlink=True)
  export(OUT/'cat_forepaws.glb',[arm]+paws)
  for o in paws:bpy.data.objects.remove(o,do_unlink=True)
 deps=bpy.context.evaluated_depsgraph_get()
 points=[]
 for o in meshes:
  evaluated=o.evaluated_get(deps)
  m=evaluated.to_mesh()
  points.extend(evaluated.matrix_world@v.co for v in m.vertices)
  evaluated.to_mesh_clear()
 REPORT[kind]={'source':str(Path('C:/zGoDot/3D')/kind),'shoulder_height_m':.32 if kind=='cat' else .64,'bones':len(arm.data.bones),'triangles':sum(len(o.data.polygons) for o in meshes),'animations':states,'bounds_blender':[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]}
 (OUT/'pet_assets.json').write_text(json.dumps(REPORT,indent=2),encoding='utf-8')
 print('PET_PREPARED',kind,REPORT[kind])
