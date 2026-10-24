"""Original synthesized dawn cue and editable real-time film scene. No recordings."""
from pathlib import Path
import numpy as np, wave
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/audio';OUT.mkdir(parents=True,exist_ok=True)
if (ROOT/'assets/cinematics/comic/opening_book.json').exists():
    raise SystemExit('The 3D opening generator is retired. Edit assets/cinematics/comic/opening_book.json and scenes/cinematics/OpeningCutscene.tscn; the original score is already included.')
rate=32000;audio=np.zeros((rate*28,2),np.float64)
def note(key,start,length,amp,pan=0):
    t=np.arange(int(length*rate))/rate;hz=440*2**((key-69)/12)
    env=(1-np.exp(-t*32))*np.exp(-t/1.9)*np.minimum(1,(length-t)/.35)
    sound=(np.sin(2*np.pi*hz*t)+.17*np.sin(2*np.pi*hz*2*t)+.045*np.sin(2*np.pi*hz*3*t))*env
    i=int(start*rate);n=min(len(sound),len(audio)-i)
    if n>0:
        audio[i:i+n,0]+=sound[:n]*amp*np.sqrt((1-pan)/2)
        audio[i:i+n,1]+=sound[:n]*amp*np.sqrt((1+pan)/2)
for bar,chord in enumerate([[45,52,57,59,64],[41,48,52,57,60],[48,55,60,62,67],[43,50,55,60,62]]):
    start=bar*6.5
    for j,key in enumerate(chord):note(key,start+j*.12,5.7,.065,-.35+j*.17)
    for j in range(8):note(chord[2+j%3]+12,start+.6+j*.72,2.2,.07,.35*np.sin(j))
for j,key in enumerate([69,72,76,79,76,74,72,67]):note(key,20.4+j*.55,2.7,.11,.2*np.sin(j))
for delay,gain in [(.19,.13),(.39,.08),(.67,.045)]:
    d=int(delay*rate);audio[d:]+=audio[:-d,::-1]*gain
audio*= (np.minimum(1,np.arange(len(audio))/(rate*1.5))*np.minimum(1,(len(audio)-np.arange(len(audio)))/(rate*3)))[:,None]
with wave.open(str(OUT/'opening_dawn.wav'),'wb') as f:
    f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate);f.writeframes((np.tanh(audio*1.4)*32767).astype('<i2').tobytes())
scene='''[gd_scene load_steps=14 format=3]
[ext_resource type="Script" path="res://scripts/cinematics/opening_cutscene.gd" id="1"]
[ext_resource type="AudioStream" path="res://assets/audio/opening_dawn.wav" id="2"]
[ext_resource type="AudioStream" path="res://assets/meow.wav" id="3"]
[ext_resource type="AudioStream" path="res://assets/paw.wav" id="4"]
[sub_resource type="SystemFont" id="Font"]
font_names = PackedStringArray("Microsoft YaHei UI", "Microsoft YaHei", "SimHei")
[sub_resource type="CameraAttributesPractical" id="Lens"]
dof_blur_amount = 0.045
dof_blur_far_transition = 2.5
'''
paths={'Actor':[(-2.8,.05,9.5),(-1.3,.05,9.1),(-.4,.05,7.3)],
 'Morning':[(2.7,1.9,12.0),(-.7,.65,9.0)],'Wake':[(-1.85,.36,8.85),(-1.9,.40,10.3)],
 'Follow':[(-4.0,.42,10.6),(-4.9,.70,11.1)],'Reveal':[(-2.0,1.1,10.3),(5.8,4.2,12.8)]}
for name,points in paths.items():
    packed=[]
    for i,p in enumerate(points):
        tangent=(np.array(points[min(len(points)-1,i+1)])-np.array(points[max(0,i-1)]))*.19
        packed.extend(list(-tangent)+list(tangent)+list(p))
    scene+=f'\n[sub_resource type="Curve3D" id="{name}"]\nbake_interval = 0.03\n_data = {{\n"points": PackedVector3Array('+', '.join(str(float(v)) for v in packed)+'),\n"tilts": PackedFloat32Array('+', '.join('0' for _ in points)+f')\n}}\npoint_count = {len(points)}\n'
scene+='\n[sub_resource type="Animation" id="Film"]\nresource_name = "opening"\nlength = 28.0\n'
tracks={'film_time':[(0,0),(28,28)],'blackout':[(0,1),(1.5,0),(28,0)],
 'title_opacity':[(0,0),(20.8,0),(22.2,1),(24.6,1),(26.1,0),(28,0)],
 'matte_amount':[(0,1),(26,1),(28,0)],'score_gain':[(0,0),(2,.7),(19,.75),(22,.95),(24.5,.95),(28,0)]}
for i,(prop,keys) in enumerate(tracks.items()):
    scene+=f'''tracks/{i}/type = "value"
tracks/{i}/path = NodePath(".:{prop}")
tracks/{i}/interp = 1
tracks/{i}/keys = {{
"times": PackedFloat32Array({', '.join(str(k[0]) for k in keys)}),
"transitions": PackedFloat32Array({', '.join('1' for k in keys)}),
"update": 0,
"values": [{', '.join(str(k[1]) for k in keys)}]
}}
'''
scene+='''
[sub_resource type="AnimationLibrary" id="Library"]
_data = {&"opening": SubResource("Film")}
[node name="OpeningCutscene" type="Node3D"]
script = ExtResource("1")
[node name="CinemaCamera" type="Camera3D" parent="."]
near = 0.025
far = 90.0
cull_mask = 23
attributes = SubResource("Lens")
[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
process_physics_priority = -10
callback_mode_process = 0
libraries = {&"": SubResource("Library")}
'''
for name in paths:scene+=f'\n[node name="{name+"Path" if name=="Actor" else name}" type="Path3D" parent="."]\ncurve = SubResource("{name}")\n'
scene+='''
[node name="Score" type="AudioStreamPlayer" parent="."]
stream = ExtResource("2")
volume_db = -80.0
[node name="Meow" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("3")
volume_db = -9.0
unit_size = 2.0
max_distance = 20.0
[node name="Paw" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("4")
volume_db = -14.0
unit_size = 1.6
max_distance = 12.0
[node name="CinemaUI" type="CanvasLayer" parent="."]
layer = 50
[node name="Overlay" type="Control" parent="CinemaUI"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
'''
def node(name,kind,parent,props):
    global scene
    scene+=f'\n[node name="{name}" type="{kind}" parent="{parent}"]\n'+props+'\n'
node('Top','ColorRect','CinemaUI/Overlay','anchor_right = 1.0\noffset_bottom = 55.0\nmouse_filter = 2\ncolor = Color(0.008,0.012,0.011,1)')
node('Bottom','ColorRect','CinemaUI/Overlay','anchor_top = 1.0\nanchor_right = 1.0\nanchor_bottom = 1.0\noffset_top = -55.0\nmouse_filter = 2\ncolor = Color(0.008,0.012,0.011,1)')
node('Title','VBoxContainer','CinemaUI/Overlay','anchor_left = 0.06\nanchor_right = 0.94\nanchor_top = 0.31\nanchor_bottom = 0.65\nalignment = 1\nmouse_filter = 2\ntheme_override_constants/separation = 16')
style='theme_override_fonts/font = SubResource("Font")\ntheme_override_colors/font_color = Color(0.96,0.91,0.79,1)\ntheme_override_colors/font_shadow_color = Color(0,0,0,0.65)\ntheme_override_constants/shadow_offset_y = 2\nmouse_filter = 2\n'
for name,caption,size in [('Chapter','每个家，都有一位小小的主人。',18),('Name','猫咪模拟器',64),('Subtitle','猫 屋 日 记   /   清 晨 篇',16)]:
    node(name,'Label','CinemaUI/Overlay/Title',f'layout_mode = 2\ntext = "{caption}"\nhorizontal_alignment = 1\ntheme_override_font_sizes/font_size = {size}\n'+style)
node('Location','Label','CinemaUI/Overlay','anchor_top = 1.0\nanchor_bottom = 1.0\noffset_left = 36.0\noffset_top = -42.0\noffset_right = 390.0\noffset_bottom = -15.0\ntext = "清晨 06:12  /  花园别墅"\ntheme_override_font_sizes/font_size = 16\n'+style)
node('Skip','Button','CinemaUI/Overlay','anchor_left = 1.0\nanchor_top = 1.0\nanchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = -170.0\noffset_top = -46.0\noffset_right = -28.0\noffset_bottom = -14.0\ntext = "Esc  跳过开场"\nflat = true\nfocus_mode = 0\ntheme_override_fonts/font = SubResource("Font")\ntheme_override_font_sizes/font_size = 15')
node('Black','ColorRect','CinemaUI/Overlay','anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\ncolor = Color(0,0,0,1)')
target=ROOT/'scenes/cinematics';target.mkdir(parents=True,exist_ok=True)
(target/'OpeningCutscene.tscn').write_text(scene,encoding='utf8')
(target/'OpeningPreview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/opening_preview.gd" id="1"]\n[node name="OpeningPreview" type="Node"]\nscript = ExtResource("1")\n',encoding='utf8')
print('Created original 28-second stereo cue and editable cinematic scene.')
