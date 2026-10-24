import bpy, math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.6
 return m
peel=mat('Ripe golden banana peel',(.74,.54,.07));brown=mat('Dried brown stem',(.18,.075,.018))
N=40;M=20;verts=[];faces=[]
for i in range(N+1):
 t=i/N;c=Vector((.25*(t-.5),.008*math.sin(math.pi*t),.031+.044*(2*t-1)**2))
 tangent=Vector((.25,.008*math.pi*math.cos(math.pi*t),.176*(2*t-1))).normalized()
 u=Vector((0,1,0));v=tangent.cross(u).normalized()
 radius=.023*(math.sin(math.pi*t)**.45)+.003
 for j in range(M):
  a=math.tau*j/M;r=radius*(1+.045*math.cos(5*a))
  verts.append(c+r*(math.cos(a)*u+math.sin(a)*v))
for i in range(N):
 for j in range(M):faces.append((i*M+j,i*M+(j+1)%M,(i+1)*M+(j+1)%M,(i+1)*M+j))
faces.extend([tuple(reversed(range(M))),tuple(N*M+j for j in range(M))])
mesh=bpy.data.meshes.new('Curved five-ridged banana mesh');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('BananaPeel',mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(peel)
uv=mesh.uv_layers.new(name='Banana peel unwrap')
for poly in mesh.polygons:
 poly.use_smooth=True
 for li in poly.loop_indices:
  index=mesh.loops[li].vertex_index;uv.data[li].uv=(index//M/N,index%M/M)
image=bpy.data.images.new('BananaSkin',width=256,height=128)
pixels=[]
for y in range(128):
 for x in range(256):
  edge=max(0,abs(x/255-.5)*2-.88)*3
  fleck=.17 if math.sin(x*29.3+y*7.13)*math.cos(x*3.11-y*13.7)>.985 else 0
  rib=.022*math.cos(y/128*math.tau*5)
  pixels.extend((max(.05,.74-edge-fleck+rib),max(.025,.54-edge*.8-fleck*.7+rib),.065,1))
image.pixels=pixels
image.filepath_raw=str(R/'furniture_pack/textures/banana_skin.png');image.file_format='PNG';image.save()
node=peel.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
peel.node_tree.links.new(node.outputs['Color'],peel.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for side in [-1,1]:
 a=Vector((side*.123,0,.074));b=Vector((side*(.148 if side==1 else .132),0,.09 if side==1 else .078))
 bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.006,radius2=.0035,depth=(b-a).length,location=(a+b)/2)
 stem=bpy.context.object;stem.name='Stalk' if side==1 else 'Blossom tip';stem.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();stem.data.materials.append(brown)
 for p in stem.data.polygons:p.use_smooth=True
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(R/'furniture_pack/authoring/easter_banana.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'furniture_pack/models/easter_banana.glb'),export_format='GLB',export_animations=False,export_yup=True)
print('BANANA_EXPORTED')

