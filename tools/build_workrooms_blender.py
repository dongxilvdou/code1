"""Blender 5.x: reusable, metre-scale workshop and computer-room furnishings.
Author in Godot axes (Y up, furniture front +Z), export glTF with Y up.
"""
import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];PACK=ROOT/'furniture_pack'
OUT=PACK/'models';OUT.mkdir(exist_ok=True)
SRC=PACK/'authoring';SRC.mkdir(exist_ok=True);(SRC/'.gdignore').write_text('')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
materials={};assets=[];parent=None;objects=[]
def color(hex):return tuple((int(hex[i:i+2],16)/255)**2.2 for i in (0,2,4))+(1,)
def mat(key,hex,rough=.65,metal=0,glow=0):
    m=bpy.data.materials.new(key);m.diffuse_color=color(hex);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color(hex)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if glow:p.inputs['Emission Color'].default_value=color(hex);p.inputs['Emission Strength'].default_value=glow
    materials[key]=m;return m
for a in [('wood','a17c52',.68,0),('darkwood','66533e',.7,0),('metal','27343a',.35,.65),('ivory','e7e5db',.65,0),
          ('paper','ede8d7',.95,0),('ink','52616b',.9,0),('green','446d60',.88,0),('steel','a0a7a5',.3,.8),
          ('graphite','141d23',.6,.1),('rubber','232b30',.96,0),('blue','52748a',.6,0),('orange','c58148',.7,0),
          ('pink','b97d79',.8,0),('key','48565e',.8,0),('cyan','67a9b2',.45,.1,.55)]:mat(*a)
def xyz(p):return (p[0],-p[2],p[1])
def record(o,name,key):
    o.name=name;o.parent=parent;o.data.materials.append(materials[key]);objects.append(o)
    return o
def box(name,p,s,key,bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object
    o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Soft manufactured edges','BEVEL');m.width=min(bevel,min(s)*.45);m.segments=3
        bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=m.name)
    return record(o,name,key)
def rod(name,a,b,r,key,vertices=24):
    a=Vector(xyz(a));b=Vector(xyz(b));d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)*.5)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    for poly in o.data.polygons:poly.use_smooth=True
    return record(o,name,key)
def begin(name):
    global parent,objects
    parent=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(parent);objects=[]
def finish(name,title,dimensions,features):
    # Join static pieces: compact material-based draw calls rather than per-key objects.
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    body=bpy.context.object;body.name=name+'_Mesh'
    bpy.context.view_layer.update()
    bounds=np.array([body.matrix_world@Vector(c) for c in body.bound_box])
    actual=(bounds.max(0)-bounds.min(0))[[0,2,1]]
    parent.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,
        export_yup=True,export_animations=False,export_skins=False,export_extras=True)
    assets.append(dict(id=name,name=title,dimensions_m=[round(float(v),4) for v in actual],features=features,model='res://furniture_pack/models/'+name+'.glb'))
    parent.location.x=(len(assets)-1)*2.8

# 1. Warm oak working desk; a useful wide desk for both rooms.
begin('work_desk')
box('Oak worktop',(0,.752,0),(1.8,.052,.76),'wood',.018)
for x in [-.72,.72]:
    box('Steel foot',(x,.027,0),(.085,.055,.64),'metal',.012)
    box('Column',(x,.38,0),(.065,.70,.085),'metal',.006)
box('Cross brace',(0,.58,.08),(1.48,.065,.05),'metal')
box('Cable tray',(0,.66,-.19),(1.15,.06,.16),'graphite')
box('Control switch',(.63,.716,.338),(.12,.018,.027),'graphite',.004)
finish('work_desk','1.8 米木面工作桌',[1.8,.778,.76],['圆角桌面','金属桌腿','理线槽'])

# 2. A4 drafting sheet, notebook, real 30cm ruler, writing implements and tools.
begin('drafting_kit')
box('Cutting mat',(0,.004,0),(.63,.008,.40),'green',.006)
for i in range(13):box('Mat grid',(-.30+i*.05,.0085,0),(.0005,.0006,.38),'ivory',0)
for i in range(8):box('Mat grid',(0,.0085,-.175+i*.05),(.61,.0006,.0005),'ivory',0)
box('A4 paper',(-.025,.010,0),(.297,.0015,.210),'paper',.001)
for x,z,w,d in [(-.06,0,.10,.08),(.04,0,.07,.08),(-.015,-.06,.19,.001),(-.08,.065,.12,.001)]:
    box('Pencil plan', (x,.0113,z),(w,.0002,.00065),'ink',0)
    if d>.01:
        for s in [-1,1]:box('Plan wall',(x+s*w/2,.0113,z),(.00065,.0002,d),'ink',0)
box('Thirty cm ruler',(.025,.014,.145),(.30,.004,.022),'ivory',.001)
for i in range(61):box('Ruler graduations',(-.12+i*.005,.0163,.148),(.0007,.0003,.012 if i%10==0 else .007 if i%2==0 else .004),'ink',0)
rod('Pencil',(-.18,.016,-.10),(-.16,.016,.075),.003,'orange',12)
rod('Pencil tip',(-.16,.016,.075),(-.157,.016,.086),.0014,'graphite',12)
rod('Pen',(.19,.017,-.10),(.22,.017,.07),.004,'blue',16)
box('Eraser',(.22,.019,.11),(.035,.016,.018),'pink',.004)
box('Notebook',(-.24,.020,-.035),(.09,.020,.135),'darkwood',.004)
for i in range(6):box('Notebook page',(-.24,.021+i*.001,-.035),(.084,.0004,.13),'paper',0)
rod('Screwdriver handle',(.25,.025,-.15),(.25,.025,-.07),.012,'orange')
rod('Screwdriver shaft',(.25,.025,-.07),(.25,.025,-.015),.002,'steel',12)
rod('Precision driver',(.29,.024,-.14),(.29,.024,-.03),.005,'graphite',16)
box('Small square head',(-.20,.03,.15),(.047,.028,.022),'steel',.005)
rod('Small hammer handle',(-.2,.023,.15),(-.28,.023,.06),.006,'wood',16)
finish('drafting_kit','纸笔尺子与桌面工具套装',[.63,.05,.40],['A4 图纸','30cm 刻度尺','铅笔','签字笔','橡皮','笔记本','螺丝刀','小锤'])

# 3. Double screens with restrained, fictional desktop windows.
screen=mat('screen','92b1b5',.4,0,.35)
image=bpy.data.images.new('Desktop_canvas',width=512,height=288)
y,x=np.mgrid[0:288,0:512];pixels=np.zeros((288,512,4),np.float32);pixels[:,:,:3]=np.array([.042,.084,.105]);pixels[:,:,3]=1
pixels[25:240,28:305,:3]=[.11,.18,.20];pixels[40:215,44:290,:3]=[.24,.34,.35]
for row in range(5):pixels[65+row*24:70+row*24,60:240-row*12,:3]=[.50,.61,.58]
pixels[35:220,325:484,:3]=[.09,.15,.19]
for i in range(6):pixels[60+i*21:65+i*21,340:470,:3]=[.28,.50,.57]
pixels[4:18,12:500,:3]=[.045,.075,.085]
image.pixels.foreach_set(pixels.ravel());image.update();image.pack()
texture=screen.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image
shader=screen.node_tree.nodes.get('Principled BSDF');screen.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color']);screen.node_tree.links.new(texture.outputs['Color'],shader.inputs['Emission Color'])
begin('dual_monitor')
for cx in [-.315,.315]:
    box('27 inch bezel',(cx,.375,0),(.615,.358,.035),'graphite',.009)
    display=box('LCD screen',(cx,.379,.019),(.584,.326,.003),'screen',.001)
    for face in display.data.polygons:
        if face.normal.y<-.7:
            for li in face.loop_indices:
                v=display.data.vertices[display.data.loops[li].vertex_index].co
                display.data.uv_layers.active.data[li].uv=(v.x/.584+.5,v.z/.326+.5)
    box('Lower bezel',(cx,.201,.022),(.595,.012,.007),'metal',.002)
    rod('Status LED',(cx+.28,.202,.026),(cx+.282,.202,.026),.0015,'cyan',8)
    box('Monitor column',(cx,.14,-.045),(.037,.27,.045),'metal',.004)
    box('Monitor base',(cx,.014,.025),(.23,.028,.20),'metal',.01)
finish('dual_monitor','双 27 英寸显示器',[1.245,.554,.22],['双屏','金属支架','屏幕界面','状态灯'])

# 4. Input devices at sensible tabletop scale.
begin('keyboard_mouse')
box('Desk mat',(0,.003,0),(.75,.006,.30),'rubber',.008)
box('Keyboard housing',(-.095,.020,-.015),(.455,.030,.15),'graphite',.006)
for row in range(5):
    for col in range(15):
        if row==4 and 3<=col<=8:continue
        p=(-.308+col*.029,.039,-.072+row*.027)
        box('Key cap',p,(.024,.011,.022),'key',.003)
        if row<4:box('Key legend',(p[0],p[1]+.0057,p[2]),(.004,.0003,.0012),'ivory',0)
box('Spacebar',(-.15,.039,.036),(.17,.011,.022),'key',.003)
box('Palm rest',(-.095,.015,.095),(.45,.025,.045),'rubber',.007)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=xyz((.255,.025,.015)))
o=bpy.context.object;o.scale=(.035,.058,.025);record(o,'Mouse shell','graphite')
box('Mouse seam',(.255,.047,-.002),(.001,.0008,.04),'key',0)
rod('Scroll wheel',(.249,.049,-.012),(.261,.049,-.012),.005,'rubber',12)
finish('keyboard_mouse','键盘鼠标与桌垫',[.75,.053,.30],['独立键帽','图例','掌托','鼠标滚轮','桌垫'])

begin('computer_tower')
box('PC chassis',(0,.29,0),(.245,.55,.45),'graphite',.014)
box('Side panel',(-.124,.30,0),(.006,.49,.39),'metal',.004)
box('Front intake',(0,.29,.231),(.218,.48,.014),'rubber',.006)
for yy in [.15,.29,.43]:
    rod('Fan ring',(0,yy,.240),(0,yy,.246),.056,'cyan',40)
    rod('Fan face',(0,yy,.247),(0,yy,.250),.050,'graphite',40)
    rod('Fan motor',(0,yy,.250),(0,yy,.253),.014,'metal',24)
    for i in range(6):
        a=i*math.tau/6
        rod('Fan blade',(.012*math.cos(a),yy+.012*math.sin(a),.252),(.043*math.cos(a+.4),yy+.043*math.sin(a+.4),.252),.007,'key',12)
box('Power button',(.07,.571,.14),(.027,.004,.024),'metal',.005)
for xx in [-.07,-.025]:box('USB port',(xx,.571,.14),(.023,.004,.009),'rubber',.001)
for xx in [-.085,.085]:
    for zz in [-.15,.15]:box('Case foot',(xx,.01,zz),(.04,.025,.045),'rubber',.004)
finish('computer_tower','三风扇台式机主机',[.252,.574,.479],['三风扇进风口','USB 接口','电源键','散热侧板','脚垫'])

begin('audio_accessories')
for x in [-.69,.69]:
    box('Speaker',(x,.13,0),(.135,.26,.145),'graphite',.009)
    for y,r in [(.10,.043),(.205,.021)]:
        rod('Speaker rim',(x,y,.074),(x,y,.080),r,'metal',32)
        rod('Speaker cone',(x,y,.081),(x,y,.084),r*.82,'rubber',32)
box('Headphone stand',(.46,.013,.025),(.13,.026,.12),'metal',.008)
rod('Stand',(.46,.023,.025),(.46,.26,.025),.008,'metal')
for side in [-1,1]:
    box('Ear cup',(.46+side*.07,.22,.025),(.035,.075,.055),'rubber',.015)
for i in range(16):
    a=i*math.pi/15
    b=(i+1)*math.pi/15
    rod('Headband',(.46+.075*math.cos(a),.22+.085*math.sin(a),.025),(.46+.075*math.cos(b),.22+.085*math.sin(b),.025),.009,'graphite',12)
finish('audio_accessories','音箱与头戴耳机',[1.515,.32,.17],['双音箱','耳机','耳机支架'])

begin('router_power')
box('Router',(0,.025,0),(.22,.045,.14),'ivory',.009)
for xx in [-.085,.085]:rod('Antenna',(xx,.035,-.055),(xx,.19,-.09),.005,'ivory',16)
for xx in [-.065,-.035,-.005]:box('Link LED',(xx,.028,.072),(.005,.003,.001),'cyan',0)
box('Power strip',(.31,.018,0),(.09,.034,.30),'ivory',.008)
for z in [-.10,0,.10]:
    for x in [.295,.325]:box('Socket slot',(x,.0355,z),(.004,.001,.012),'graphite',.0005)
rod('Power cord',(.31,.02,-.15),(.31,.02,-.34),.0035,'rubber',12)
finish('router_power','路由器与安全插排',[.36,.19,.43],['双天线','状态灯','三位插座','电源线'])

begin('office_chair')
box('Seat cushion',(0,.465,0),(.50,.10,.47),'blue',.04)
box('Seat shell',(0,.405,-.015),(.46,.025,.43),'graphite',.01)
back=box('Lumbar backrest',(0,.855,-.225),(.49,.53,.085),'blue',.035)
back.rotation_euler.x=math.radians(-7)
box('Head support',(0,1.18,-.26),(.29,.14,.09),'blue',.035)
rod('Back support',(0,.41,-.19),(0,1.15,-.27),.018,'metal')
rod('Gas lift',(0,.10,0),(0,.41,0),.034,'steel',32)
for side in [-1,1]:
    rod('Arm support',(side*.23,.42,-.10),(side*.30,.65,-.10),.015,'metal')
    box('Soft armrest',(side*.30,.67,.005),(.065,.04,.31),'rubber',.015)
for i in range(5):
    a=i*math.tau/5
    end=(.31*math.cos(a),.065,.31*math.sin(a))
    rod('Five star base',(0,.11,0),end,.026,'graphite')
    axle=np.array([math.sin(a)*.020,0,-math.cos(a)*.020])
    center=np.array(end)+[0,-.025,0]
    rod('Caster wheel',center-axle,center+axle,.035,'rubber',24)
finish('office_chair','可调式人体工学办公椅',[.7,1.25,.7],['五爪脚轮','气压支撑','软垫','腰背支撑','头枕','扶手'])

(PACK/'workrooms_catalog.json').write_text(json.dumps({'units':'metres','front':'+Z','assets':assets},ensure_ascii=False,indent=2),encoding='utf8')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'workrooms.blend'))
print('WORKROOM_ASSETS',len(assets),flush=True)
