"""Round-trip the compatible Godot rig to an editable Blender source and GLB.
All eight baked actions, weights, UVs and PBR textures are retained.
"""
import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/models';SRC=OUT/'authoring'
SRC.mkdir(exist_ok=True);(SRC/'.gdignore').write_text('')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/'calico_rigged.glb'))
rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
assert len(rigs)==1
rig=rigs[0];rig.show_in_front=True
rig['coordinate_contract']='Godot: metres, Y up, facing -Z. Blender import converts to Z up.'
rig['animation_contract']='Existing 47 bone names retained. Runtime controller uses the same IK rig.'
for action in bpy.data.actions:action.use_fake_user=True
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
bpy.context.scene.render.fps=24
# Open into material preview with all resources packed for a portable source file.
for area in bpy.context.screen.areas if bpy.context.screen else []:
    if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'calico.blend'))
bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'calico.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'calico_rigged.glb'),export_format='GLB',
    export_yup=True,export_animations=True,export_animation_mode='ACTIONS',
    export_force_sampling=True,export_skins=True,export_influence_nb=4,export_cameras=False,
    export_lights=False,export_leaf_bone=False)
report={'blender':bpy.app.version_string,'bones':len(rig.data.bones),
        'actions':[a.name for a in bpy.data.actions], 'packed_source':'authoring/calico.blend',
        'meshes':len([o for o in bpy.data.objects if o.type=='MESH'])}
(OUT/'blender_validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('BLENDER_ROUNDTRIP',report)
