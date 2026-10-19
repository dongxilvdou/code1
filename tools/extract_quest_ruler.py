"""Split the existing drafting-kit ruler, preserving its original mesh/materials."""
import bpy, bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'furniture_pack/models/drafting_kit.glb'
out=ROOT/'furniture_pack/quest_props/ruler.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(path))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==1
original=meshes[0]
def is_ruler(co):
    p=original.matrix_world@co;x,y,z=p.x,p.z,-p.y
    return -.127<x<.177 and .0119<y<.0175 and .132<z<.158
if not any(is_ruler(p.center) for p in original.data.polygons):
    assert out.exists(),'Ruler missing from both kit and portable library'
    print('Ruler already extracted; kit is unchanged.');raise SystemExit(0)
count=0
for invert in [False,True]:
    obj=original if invert else original.copy()
    if not invert:obj.data=original.data.copy();bpy.context.collection.objects.link(obj)
    bm=bmesh.new();bm.from_mesh(obj.data)
    delete=[f for f in bm.faces if (not is_ruler(f.calc_center_median()) if not invert else is_ruler(f.calc_center_median()))]
    bmesh.ops.delete(bm,geom=delete,context='FACES');bm.to_mesh(obj.data);bm.free()
    if not invert:ruler=obj;count=len(obj.data.polygons)
assert count>100,'Original ruler was not found'
bpy.ops.object.select_all(action='DESELECT');ruler.select_set(True);bpy.context.view_layer.objects.active=ruler
bpy.context.scene.cursor.location=(.025,-.145,.012)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR');ruler.location=(0,0,0)
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=False)
ruler.hide_set(True);ruler.select_set(False)
original.select_set(True)
for p in [original.parent]:
    if p:p.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'furniture_pack/authoring/drafting_kit_separable.blend'))
print('EXTRACTED_ORIGINAL_RULER',count)
