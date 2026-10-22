"""Blender authoring pass for the five supplied basement models.

Run with Blender --background --python tools/build_basement_assets.py.
Original GLBs in C:/zGoDot/3D/under are never modified. Game coordinates:
Y up, cage doorway faces -Z, metres. Packed .blend sources retain their UVs.
"""
import bpy, bmesh, json, math, hashlib
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r'C:\zGoDot\3D\under')
OUT = ROOT/'furniture_pack/basement/models'
AUTHOR = ROOT/'furniture_pack/authoring/basement'
OUT.mkdir(parents=True, exist_ok=True)
AUTHOR.mkdir(parents=True, exist_ok=True)
(AUTHOR/'.gdignore').touch()
bpy.context.preferences.filepaths.save_version = 0
report = {}

def meshes():
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']

def bounds():
    corners = [o.matrix_world@Vector(c) for o in meshes() for c in o.bound_box]
    return [Vector(tuple(fn(v[i] for v in corners) for i in range(3))) for fn in (min,max)]

def load(name, height, turn=0):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/name))
    # Bake import transforms first; clear parents without losing world transforms.
    for o in meshes():
        world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
    for o in meshes():
        o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4)
        if turn:o.data.transform(Matrix.Rotation(turn,4,'Z'))
    bpy.context.view_layer.update()
    lo,hi=bounds();factor=height/(hi.z-lo.z)
    center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    for o in meshes():
        for v in o.data.vertices:v.co=(v.co-center)*factor
        o.data.update()
    bpy.context.view_layer.update()

def mat(name,color,metal=0,rough=.5):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m

def box(name, p, size, material, bevel=.006):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    o=bpy.context.object;o.name=name;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('Machined rounded edges','BEVEL');mod.width=bevel;mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def rod(name,a,b,radius,material):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    o.data.materials.append(material)
    for p in o.data.polygons:p.use_smooth=True
    return o

def export(name,source):
    for image in bpy.data.images:
        if image.type=='IMAGE':
            try:image.pack()
            except RuntimeError:pass
    bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/(name+'.blend')))
    if name=='cat_observation_cage':
        hinge=bpy.data.objects['DoorHinge'];door=set(hinge.children_recursive)|{hinge}
        bpy.ops.object.select_all(action='DESELECT')
        for o in meshes():o.select_set(o not in door)
        bpy.ops.export_scene.gltf(filepath=str(OUT/'cage_shell.glb'),use_selection=True,export_format='GLB',export_animations=False)
        bpy.ops.object.select_all(action='DESELECT')
        for o in door:o.select_set(True)
        hinge.location=Vector((0,0,0))
        bpy.ops.export_scene.gltf(filepath=str(OUT/'cage_door.glb'),use_selection=True,export_format='GLB',export_animations=False)
        hinge.location=Vector((-.517,.802,.045))
        bpy.context.view_layer.update()
    else:
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
    lo,hi=bounds()
    report[name]={'source':source,'source_sha256':hashlib.sha256((SOURCE/source).read_bytes()).hexdigest(),
                  'size_blender_xyz_m':list(hi-lo),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes())}

for source,name,height,turn in [
    ('medical_cart.glb','medical_cart',.92,0),
    ('medical_table.glb','examination_table',.91,0),
    ('medical_table_-_17mb.glb','instrument_table',.86,math.pi/2),
    ('the_screen_is_medical.glb','privacy_screen',1.85,math.pi/2),
]:
    load(source,height,turn)
    # Keep the supplied materials/textures and their small signs of age.
    for o in meshes():
        for m in o.data.materials:
            if m and m.use_nodes:
                p=m.node_tree.nodes.get('Principled BSDF')
                if p:p.inputs['Roughness'].default_value=max(.4,p.inputs['Roughness'].default_value)
    export(name,source)

source='square_rat_cage_-_steampunk.glb'
load(source,1.05)
o=meshes()[0];o.name='RetainedCageShell'
lo,hi=bounds();dimensions=hi-lo
# Wide, low enclosure, approx three cat body lengths. Uniform rod thickness is
# restored on the new door; the original shell keeps its authored UV and wear.
for v in o.data.vertices:
    v.co.x*=1.14/dimensions.x;v.co.y*=1.62/dimensions.y
o.data.update();bpy.context.view_layer.update()
# The input is one joined mesh, with no working door. Remove ONLY the front
# bars/centre rail, keeping the roof, tray, corners and the other three sides.
bm=bmesh.new();bm.from_mesh(o.data)
front=[f for f in bm.faces if f.calc_center_median().y>.755 and .04<f.calc_center_median().z<.982 and abs(f.calc_center_median().x)<.535]
bmesh.ops.delete(bm,geom=front,context='FACES')
loose=[v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(o.data);bm.free();o.data.update()
steel=mat('Brushed medical stainless',(.34,.39,.38),.72,.43)
enamel=mat('Aged off-white enamel',(.67,.70,.66),.25,.6)
rubber=mat('Dark rubber latch',(.035,.045,.041),0,.86)
# Door closed in the front plane, left hinge; exported hinge local axes are
# unchanged, so a Godot AnimatableBody3D can rotate just this subtree.
bpy.ops.object.empty_add(type='PLAIN_AXES',location=(-.517,.802,.045))
hinge=bpy.context.object;hinge.name='DoorHinge'
parts=[]
for x in [-.505,.505]:parts.append(box('DoorVerticalFrame',(x,.802,.512),(.024,.028,.925),enamel))
for z in [.061,.967]:parts.append(box('DoorHorizontalFrame',(0,.802,z),(1.035,.028,.025),enamel))
for i in range(17):
    x=-.476+i*.0595
    parts.append(rod('DoorBar_%02d'%i,(x,.802,.075),(x,.802,.953),.0065,steel))
parts.append(rod('DoorMiddleRail',(-.50,.802,.51),(.50,.802,.51),.008,steel))
parts.append(box('LatchPlate',(.46,.823,.39),(.09,.016,.11),enamel))
parts.append(rod('LatchHandle',(.43,.844,.39),(.49,.844,.39),.012,rubber))
for z in [.19,.80]:parts.append(rod('HingePin',(-.52,.802,z-.045),(-.52,.802,z+.045),.018,steel))
for part in parts:
    world=part.matrix_world.copy();part.parent=hinge;part.matrix_world=world
# A low removable tray lets a small cat enter without jumping a tall threshold.
box('RemovableWhiteTray',(0,0,.041),(1.055,1.51,.022),enamel,.012)
export('cat_observation_cage',source)
report['cat_observation_cage'].update({'door_width_m':1.035,'hinge_godot_xyz':[-.517,.045,-.802], 'removed_front_faces':len(front)})
(ROOT/'furniture_pack/basement/asset_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('BASEMENT_ASSETS_COMPLETE',json.dumps(report))
