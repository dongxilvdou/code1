"""Reusable metre-scale quest props. python --labels, then Blender -b --python this_file.
Authoring axes: Godot Y up, front +Z. Packed glTF materials; no particle fur.
"""
import math, json, sys, random
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'furniture_pack'/'quest_props'
OUT.mkdir(exist_ok=True)
if '--labels' in sys.argv:
    from PIL import Image, ImageDraw, ImageFont
    font_path = 'C:/Windows/Fonts/msyh.ttc'
    font = lambda n: ImageFont.truetype(font_path,n)
    for name,title,lines in [
        ('memo','今日的小清单',['开门，走走，看看这个家。','把杯子放回杯垫，读一读纸条。','记得照顾自己，也照顾阿嚼。']),
        ('memo2','第二天的小清单',['收好三件衣服，放进洗衣机。','书房的尺子，可以帮你取回毛线球。','叼着狗盘，到厨房水龙头冲洗。']),
        ('memo3','第三天的小清单',['把三本书放回原来的书架。','检查水槽下的水管，给花浇水。','也别忘了阿嚼的饭。']),
        ('letter','致 小小的探险家',['今天请自己准备午餐。','冰箱侧面的机关，为你准备。','愿你和阿嚼都吃得暖暖的。']),
        ('clues','观察手记',['照片  C-031 / 阶段 II','镜头  水槽下的一点红光','玩具  D-017 / 阿嚼']),
        ('book_red','家的小风景',['HOME & GARDEN','VOL. 01']),
        ('book_blue','温柔的日常',['A QUIET LIFE','VOL. 02']),
        ('book_gold','四季植物志',['BOTANICAL NOTES','VOL. 03']),
    ]:
        im=Image.new('RGB',(768,1024),'#e9dfc7');d=ImageDraw.Draw(im)
        rng=random.Random(14)
        for _ in range(12000):
            x,y=rng.randrange(768),rng.randrange(1024);c=rng.choice(['#e2d7bd','#e5dbc3','#eee5ce'])
            d.point((x,y),fill=c)
        d.rectangle((32,32,736,992),outline='#a99269',width=3)
        d.text((68,100),title,font=font(50),fill='#384a43')
        d.line((68,190,700,190),fill='#b79059',width=4)
        for i,line in enumerate(lines):
            d.text((68,270+i*145),line,font=font(27),fill='#52635a')
            d.line((68,330+i*145,690,330+i*145),fill='#cfc3a9',width=1)
        d.text((70,900),'MISO  /  HOME',font=font(23),fill='#867b61')
        if name.startswith('book_'):
            key=name.removeprefix('book_');base={'red':'#944e43','blue':'#426676','gold':'#92763e'}[key]
            im=Image.new('RGB',(768,1024),base);d=ImageDraw.Draw(im)
            d.rounded_rectangle((38,38,730,986),radius=12,outline='#d9c99c',width=4)
            d.text((80,115),title,font=font(62),fill='#f0e6ca')
            d.text((84,220),lines[0],font=font(28),fill='#d7c7a0')
            # Printed botanical cover art, rather than an unmarked colour block.
            d.line((380,790,395,385),fill='#dfcfaa',width=5)
            for j in range(6):
                y=450+j*55;sign=-1 if j%2 else 1
                d.arc((380-105 if sign<0 else 390,y-45,395 if sign<0 else 500,y+20),0,350,fill='#dfcfaa',width=3)
                d.line((390,y+18,312 if sign<0 else 465,y-22),fill='#dfcfaa',width=2)
            d.text((82,884),lines[1],font=font(28),fill='#ecdfbd')
        im.save(OUT/(name+'.png'))
    for i,count in enumerate([8,2,7,1,9,3,8]):
        im=Image.new('RGB',(512,512),'#eee6cf');d=ImageDraw.Draw(im)
        d.rectangle((0,0,512,106),fill='#477065');d.text((26,20),'阿嚼 · 日常照护',font=font(34),fill='#f1e5ca')
        d.text((28,144),'No. %02d'%(i+1),font=font(58),fill='#344e47')
        d.text((28,250),'剩余 %d 份'%count,font=font(57),fill='#805f38')
        d.line((28,346,484,346),fill='#b8aa88',width=2)
        d.text((28,380),'按清单选择 · 避光保存',font=font(26),fill='#546c60')
        im.save(OUT/('medicine_%d.png'%i))
    print('Quest labels generated');sys.exit(0)

import bpy
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
M={};objects=[];catalog=[]
def xyz(p):return (p[0],-p[2],p[1])
def mat(key,c,rough=.65,metal=0,texture=None):
    m=bpy.data.materials.new(key);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    col=tuple((int(c[i:i+2],16)/255)**2.2 for i in (0,2,4))+(1,)
    p.inputs['Base Color'].default_value=col;p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    m.diffuse_color=col
    if texture:
        node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(texture));node.image.pack()
        m.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
    M[key]=m;return m
for a in [('cream','dfdccb',.34),('paper','e7dfca',.9),('ink','384c47',.8),('sage','6e9285',.4),
          ('red','9d5146',.65),('blue','507485',.65),('gold','b69a58',.65),('brass','b89a62',.32,.65),
          ('steel','9ca9ab',.28,.7),('black','253333',.55),('dark','142622',.85),('cork','927251',.92),
          ('amber','8d5834',.25),('water','679a9d',.18,.22),('fish','7f9c9d',.38,.26),('fin','546e72',.65),
          ('cooked','b87a44',.6),('flesh','e0c69b',.8),('rubber','3b514d',.85),('stitch','cabbb0',.9)]:mat(*a)
mat('cloth','ffffff',.95,texture=ROOT/'furniture_pack/textures/linen_weave.png')
for key in ['memo','letter','clues','book_red','book_blue','book_gold']+['medicine_%d'%i for i in range(7)]:
    mat(key,'ffffff',.85,texture=OUT/(key+'.png'))
def record(o,name,key):
    o.name=name;o.data.materials.append(M[key]);objects.append(o);return o
def box(name,p,s,key,bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=min(bevel,min(s)*.35);mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    return record(o,name,key)
def ball(name,p,s,key):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=.5,location=xyz(p))
    o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons:f.use_smooth=True
    return record(o,name,key)
def mesh(name,verts,faces,key):
    data=bpy.data.meshes.new(name);data.from_pydata([xyz(v) for v in verts],[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    return record(o,name,key)
def rod(name,a,b,r,key,verts=20):
    a=Vector(xyz(a));b=Vector(xyz(b));d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    for f in o.data.polygons:f.use_smooth=True
    return record(o,name,key)
def curve(name,points,r,key,resolution=6,bevel=2):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=resolution;c.bevel_depth=r;c.bevel_resolution=bevel
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for b,p in zip(s.bezier_points,points):b.co=xyz(p);b.handle_left_type='AUTO';b.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
    return record(o,name,key)
def lathe(name,profile,key,c=(0,0,0),n=48):
    v=[(c[0]+r*math.cos(j*2*math.pi/n),c[1]+y,c[2]+r*math.sin(j*2*math.pi/n)) for r,y in profile for j in range(n)]
    f=[]
    for k in range(len(profile)-1):
        for j in range(n):a=k*n+j;b=k*n+(j+1)%n;f.append((a,b,b+n,a+n))
    o=mesh(name,v,f,key)
    for face in o.data.polygons:face.use_smooth=True
    return o
def decal(name,p,w,h,key,vertical=False):
    if vertical:v=[(-w/2,-h/2,0),(w/2,-h/2,0),(w/2,h/2,0),(-w/2,h/2,0)]
    else:v=[(-w/2,0,h/2),(w/2,0,h/2),(w/2,0,-h/2),(-w/2,0,-h/2)]
    o=mesh(name,[(p[0]+a,p[1]+b,p[2]+c) for a,b,c in v],[(0,1,2,3)],key)
    uv=o.data.uv_layers.new(name='UVMap')
    for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=co
    return o
def text(name,value,p,size,key):
    c=bpy.data.curves.new(name,'FONT');c.body=value;c.size=size;c.align_x='CENTER';c.extrude=.0001
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.location=xyz(p);o.rotation_euler=(math.pi/2,0,0)
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
    return record(o,name,key)
def begin():
    global objects
    bpy.ops.object.select_all(action='DESELECT');objects=[]
def finish(name,title):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    # Local origin stays on the ground / tabletop, irrespective of first component origin.
    scene=bpy.context.scene;scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_skins=False)
    tris=sum(len(p.vertices)-2 for p in o.data.polygons)
    catalog.append({'id':name,'name':title,'triangles':tris,'materials':len(o.data.materials),'units':'metres'})
    o.hide_set(True);o.select_set(False)

for i,key in enumerate(['red','blue','gold']):
    begin()
    box('Page block',(0,.020,0),(.164,.030,.228),'paper',.002)
    for y in [.003,.039]:box('Clothbound cover',(0,y,0),(.182,.006,.246),key,.003)
    box('Rounded spine',(-.087,.021,0),(.012,.038,.246),key,.004)
    for y in [.010,.014,.018,.022,.026,.030]:
        rod('Page edge',(.083,y,-.109),(.083,y,.109),.00035,'cork',8)
    for z in [-.09,.09]:box('Spine foil',(-.094,.021,z),(.001,.028,.005),'brass',.0003)
    decal('Printed cover',(0,.0422,0),.157,.218,'book_'+key)
    box('Ribbon bookmark',(.035,.024,.13),(.010,.001,.035),key,.0003)
    finish('book_'+key,['红色硬壳园艺书','蓝色硬壳日记','金色植物图鉴'][i])

for key,title in [('memo','任务便笺'),('letter','折好的来信'),('clues','线索手记')]:
    begin();box('Paper stack',(0,.002,0),(.235,.004,.31),'paper',.001)
    if key=='clues':
        box('Bound cover',(0,.001,0),(.25,.008,.325),'sage',.003)
        for z in [-.12,-.08,-.04,0,.04,.08,.12]:curve('Binding loop',[(-.12,.006,z),(-.132,.014,z),(-.136,.005,z)],.0015,'brass')
    decal('Printed paper',(0,.010 if key=='clues' else .0042,0),.226,.298,key)
    if key=='letter':
        curve('Envelope fold',[(-.115,.0048,.15),(0,.006,-.005),(.115,.0048,.15)],.0006,'cork')
        ball('Wax seal',(0,.007,-.004),(.026,.005,.026),'red')
    finish(key,title)

begin()
lathe('Glazed ceramic',[(0,0),(.047,0),(.063,.008),(.071,.145),(.070,.16),(.062,.16),(.060,.145),(.053,.016),(0,.016)],'cream')
curve('Mug handle',[(.065,.12,0),(.105,.13,0),(.118,.08,0),(.10,.043,0),(.063,.05,0)],.009,'cream')
lathe('Tea surface',[(0,.12),(.061,.12)],'water')
for y in [.025,.031]:lathe('Glazed stripe',[(.064,y),(.0645,y+.003)],'sage')
finish('mug','有杯柄与杯口的陶瓷杯')
begin();lathe('Cork coaster',[(0,0),(.10,0),(.105,.005),(.10,.012),(0,.012)],'cork')
lathe('Stitched rim',[(.091,.0125),(.094,.0125)],'brass');finish('coaster','软木杯垫')

begin()
lathe('Open can body',[(0,0),(.09,0),(.116,.025),(.12,.20),(.112,.235),(.102,.235),(.108,.20),(.104,.03),(0,.03)],'sage')
curve('Loop handle',[(-.10,.035,0),(-.20,.07,0),(-.21,.21,0),(-.13,.26,0),(-.10,.20,0)],.012,'sage')
curve('Hollow spout',[(.10,.05,0),(.18,.11,0),(.25,.22,0),(.29,.26,0)],.022,'sage')
lathe('Top brass rim',[(.105,.233),(.116,.233),(.116,.239),(.105,.239)],'brass')
rose=ball('Sprinkler rose',(.30,.27,0),(.060,.026,.068),'steel');rose.rotation_euler.y=-.7
for i in range(9):ball('Spout holes',(.294+math.sin(i*2.4)*.017,.283,math.cos(i*2.4)*.022),(.004,.002,.004),'dark')
finish('watering_can','开口金属浇花壶')

begin();lathe('Ceramic bowl',[(0,0),(.105,0),(.15,.045),(.148,.070),(.135,.075),(.123,.055),(.097,.018),(0,.018)],'cream')
lathe('Rim glaze',[(.141,.065),(.149,.065),(.147,.073),(.139,.073)],'sage')
lathe('Rubber foot',[(.093,0),(.106,0),(.106,.005),(.093,.005)],'rubber')
text('Bowl brand','MISO',(0,.030,.127),.021,'sage');finish('pet_bowl','带凹槽与防滑圈的陶瓷食碗')

begin()
box('Rounded dispenser shell',(0,.37,0),(.63,.74,.44),'cream',.055)
box('Recessed front',(0,.43,.223),(.53,.31,.014),'sage',.025)
box('Drip tray',(0,.025,.24),(.59,.045,.28),'rubber',.012)
for x in [-.155,.155]:
    lathe('Hopper',[(0,.70),(.118,.70),(.13,.77),(.125,1.02),(0,1.02)],'amber',c=(x,0,0))
    lathe('Hopper lid',[(0,1.02),(.136,1.02),(.136,1.05),(0,1.05)],'sage',c=(x,0,0))
    box('Pour chute',(x,.17,.26),(.115,.08,.12),'steel',.008)
    box('Chute opening',(x,.13,.27),(.09,.005,.08),'dark',.004)
for col,count in enumerate([2,4,1]):
    for row in range(count):
        x=-.17+col*.17;y=.54-row*.054
        ball('Code paw pad',(x,y,.236),(.026,.021,.004),'brass')
        for toe in range(3):ball('Code toe',(x+(toe-1)*.013,y+.018,.237),(.01,.012,.004),'brass')
text('Brand','MISO / AJIAO',(0,.66,.228),.026,'sage')
for x in [-.29,.29]:
    for z in [-.17,.17]:ball('Feet',(x,.01,z),(.04,.02,.04),'rubber')
finish('feeder','双仓宠物自动喂食器')

for color in ['blue','red','gold']:
    begin()
    # T-shirt outline, gently rumpled mesh with sewn hem and neck opening.
    outline=[(-.085,-.15),(.085,-.15),(.09,.055),(.17,.01),(.22,.075),(.125,.135),(.045,.14),
             (-.045,.14),(-.125,.135),(-.22,.075),(-.17,.01),(-.09,.055)]
    verts=[(x,.014+.007*math.sin(x*44+z*16),z) for x,z in outline]+[(0,.027,0)]
    body=mesh('Draped cotton shirt',verts,[(i,(i+1)%12,12) for i in range(12)],color)
    mod=body.modifiers.new('Cloth thickness','SOLIDIFY');mod.thickness=.003
    bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=mod.name)
    curve('Neck rib',[(-.047,.018,.14),(-.04,.023,.11),(0,.023,.095),(.04,.023,.11),(.047,.018,.14)],.005,'stitch')
    curve('Bottom hem',[(-.085,.012,-.143),(0,.012,-.143),(.085,.012,-.143)],.0012,'stitch')
    for s in [-1,1]:curve('Fabric crease',[(s*.075,.018,-.12),(s*.04,.027,-.03),(s*.06,.021,.07)],.001,color)
    box('Sewn label',(-.066,.02,-.12),(.023,.001,.012),'paper',.001)
    finish('shirt_'+color,'棉质待洗上衣 / '+color)

begin()
rod('Mailbox post',(0,0,0),(0,1.18,0),.065,'black')
box('Mounting foot',(0,.025,0),(.25,.05,.22),'black',.02)
box('Rounded letter box',(0,1.32,0),(.54,.40,.36),'sage',.065)
box('Door inset',(0,1.31,.186),(.45,.29,.016),'cream',.025)
box('Letter slot',(0,1.39,.197),(.34,.038,.006),'dark',.012)
box('Rain flap',(0,1.417,.205),(.36,.016,.035),'steel',.005)
rod('Door handle',(-.075,1.23,.215),(.075,1.23,.215),.009,'brass')
for x in [-.20,.20]:rod('Hinge',(x,1.18,.20),(x,1.22,.20),.009,'steel')
text('House number','017',(0,1.09,.189),.04,'cream')
finish('mailbox','弧角信箱、投信口与门锁')

for cooked in [False,True]:
    begin();key='cooked' if cooked else 'fish';L=.34 if not cooked else .20
    profiles=[(-L*.5,.004),(-L*.40,.034),(-L*.15,.053),(L*.22,.049),(L*.46,.028),(L*.50,.008)]
    verts=[];faces=[]
    for x,r in profiles:
        for j in range(20):a=j*math.tau/20;verts.append((x,.035+math.sin(a)*r*.65,math.cos(a)*r))
    for i in range(len(profiles)-1):
        for j in range(20):a=i*20+j;b=i*20+(j+1)%20;faces.append((a,b,b+20,a+20))
    o=mesh('Tapered fish body',verts,faces,key)
    for f in o.data.polygons:f.use_smooth=True
    mesh('Tail fin',[(-L*.49,.038,0),(-L*.76,.03,-.065),(-L*.67,.032,0),(-L*.76,.03,.065)],[(0,1,2),(0,2,3)],'fin' if not cooked else 'cooked')
    for s in [-1,1]:
        ball('Silver eye',(L*.35,.055,s*.027),(.019,.009,.012),'brass')
        ball('Eye pupil',(L*.35,.059,s*.029),(.010,.005,.007),'black')
        curve('Gill',[(L*.20,.055,s*.038),(L*.22,.033,s*.047),(L*.18,.013,s*.032)],.0012,'fin')
    mesh('Dorsal fin',[(-.06,.06,0),(-.02,.10,0),(.05,.063,0)],[(0,1,2)],'fin')
    for x in [-.09,-.045,0,.045]:curve('Skin marking',[(x,.063,-.019),(x+.01,.071,0),(x,.063,.019)],.001,'fin' if not cooked else 'cork')
    if cooked:lathe('Serving plate',[(0,0),(.13,0),(.16,.012),(.15,.023),(.12,.014),(0,.013)],'cream')
    finish('half_fish' if cooked else 'fish','半份烤鱼与餐盘' if cooked else '有鱼鳍鱼尾鳞纹的鲜鱼')

begin();ball('Wound yarn core',(0,0,0),(.18,.18,.18),'gold')
for i in range(28):
    pts=[]
    angle=i*.67
    for j in range(21):
        a=j*math.tau/20;r=.091
        pts.append((r*math.cos(a)*math.cos(angle),r*math.sin(a),r*math.cos(a)*math.sin(angle)))
    curve('Wool strand',pts,.0015,'cork' if i%4==0 else 'gold',resolution=1,bevel=1)
curve('Loose thread',[(.02,-.075,.05),(.14,-.085,.10),(.23,-.085,.04),(.29,-.085,.10)],.002,'gold')
finish('yarn','绕线毛球与松开的线头')
begin();box('Chew bone shaft',(0,.027,0),(.22,.05,.07),'cream',.024)
for x in [-.12,.12]:
    for z in [-.033,.033]:ball('Bone ends',(x,.03,z),(.085,.064,.075),'cream')
text('Engraved ID','D-017',(0,.054,.019),.022,'cork').rotation_euler=(0,0,0)
finish('bone','带编号的磨牙骨头')

for i,count in enumerate([8,2,7,1,9,3,8]):
    begin()
    lathe('Apothecary bottle',[(0,0),(.036,0),(.042,.012),(.042,.13),(.033,.15),(.027,.154),(.027,.175),(0,.175)],'amber')
    lathe('Safety cap',[(0,.17),(.034,.17),(.035,.176),(.035,.198),(.032,.202),(0,.202)],'cream')
    for j in range(24):
        a=j*math.tau/24;rod('Grip ridges',(.035*math.cos(a),.177,.035*math.sin(a)),(.035*math.cos(a),.194,.035*math.sin(a)),.0007,'paper',8)
    decal('Care label',(0,.09,.0424),.064,.085,'medicine_%d'%i,True)
    finish('medicine_%d'%i,'照护药瓶 %d / 余量 %d'%(i+1,count))

begin()
lathe('Woven cat bed',[(0,0),(.34,0),(.43,.035),(.43,.12),(.39,.15),(.34,.125),(.32,.045),(0,.045)],'sage')
ball('Linen cushion',(0,.066,0),(.65,.08,.65),'paper')
for i in range(36):
    a=i*math.tau/36;curve('Basket weave',[(.42*math.cos(a),.04,.42*math.sin(a)),(.416*math.cos(a+.018),.11,.416*math.sin(a+.018))],.0025,'stitch')
finish('cat_bed','带围边和软垫的猫窝')

begin();box('Storage stool seat',(0,.31,0),(.43,.025,.42),'cork',.014)
for x in [-.16,.16]:
    for z in [-.15,.15]:rod('Tapered foot',(x*1.15,.012,z*1.15),(x,.30,z),.019,'cork')
for x in [-.16,.16]:rod('Cross brace',(x,.10,-.15),(x,.10,.15),.010,'cork')
finish('step_stool','实木圆角脚凳')

begin();box('Rounded mechanism case',(0,0,0),(.023,.21,.20),'sage',.012)
for i in range(3):
    for j in range(3):
        box('Number tile',(-.016,(1-i)*.057,(j-1)*.057),(.012,.05,.05),'cream',.005)
        # Side-mounted panel readable from kitchen counter.
        for k in range(1+(i*3+j)%4):ball('Paw markings',(-.023,(1-i)*.057+.008*k-.015,(j-1)*.057),(.002,.004,.004),'brass')
finish('fridge_lock','冰箱侧面滑块机关面板')

src=ROOT/'furniture_pack/authoring';src.mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(src/'quest_props.blend'))
if (OUT/'ruler.glb').exists():
    import struct
    data=(OUT/'ruler.glb').read_bytes();length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length]);triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
    catalog.append({'id':'ruler','name':'从原书房工具套装中分离的 30cm 尺子','triangles':triangles,'units':'metres','source':'existing drafting_kit'})
(OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
print('QUEST_PROPS_DONE',len(catalog),sum(a['triangles'] for a in catalog))
