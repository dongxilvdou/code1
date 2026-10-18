"""Round reusable dog bed, metres, shared authoring source and GLB."""
import bpy, math
from pathlib import Path
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,roughness):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=roughness
 return m
wood=mat('Warm walnut frame',(.20,.12,.065),.72)
cloth=mat('Sage woven bolster',(.27,.34,.29),.95)
pillow=mat('Cream cotton cushion',(.65,.57,.43),.96)
seam=mat('Woven piping',(.16,.20,.16),.93)
def lathe(name,profile,material,dip=False):
 vertices=[];faces=[];segments=96;n=len(profile)
 for i in range(segments):
  a=math.tau*i/segments;entry=max(0,-math.sin(a))**8
  for r,z in profile:vertices.append((r*math.cos(a),r*math.sin(a),z-(.065*entry if dip else 0)))
 for i in range(segments):
  for j in range(n-1):faces.append((i*n+j,((i+1)%segments)*n+j,((i+1)%segments)*n+j+1,i*n+j+1))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(material)
 for p in mesh.polygons:p.use_smooth=True
 uv=mesh.uv_layers.new(name='Round woven surface')
 for p in mesh.polygons:
  for li in p.loop_indices:
   vi=mesh.loops[li].vertex_index;uv.data[li].uv=(vi//n/segments,(vi%n)/(n-1))
 return o
lathe('Circular walnut plinth',[(0,.015),(.515,.015),(.545,.025),(.55,.040),(.545,.055),(.515,.065),(0,.065)],wood)
lathe('Soft round sleeping cushion',[(0,.064),(.39,.064),(.46,.075),(.475,.10),(.45,.127),(.36,.138),(0,.143)],pillow)
lathe('Continuous round bolster',[(.493+.055*math.cos(math.tau*j/24),.153+.061*math.sin(math.tau*j/24)) for j in range(25)],cloth,True)
lathe('Tailored cushion piping',[(.449+.003*math.cos(math.tau*j/12),.128+.003*math.sin(math.tau*j/12)) for j in range(13)],seam)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(R/'furniture_pack/authoring/dog_nest.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'furniture_pack/models/dog_nest.glb'),export_format='GLB',export_animations=False,export_yup=True)
print('ROUND_DOG_NEST_EXPORTED')
