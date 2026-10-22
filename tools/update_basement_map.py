"""Update only the basement plan; other floors and their room IDs are preserved."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1];MAP=ROOT/'villa_maps'
path=MAP/'layout.json';layout=json.loads(path.read_text(encoding='utf8'))
def region(id,name,x,z,w,d,label):
    return dict(id=id,name=name,polygon_xz=[[x,z],[x+w,z],[x+w,z+d],[x,z+d]],label_xz=label)
spec=dict(id='basement',name='地下医学实验室',world_rect_xz=[-5.85,-5.8,12.2,7.9],pixel_size=[1024,1024],
          base='assets/runtime/basement_base.png',structure='assets/runtime/basement_structure.png',labels='assets/runtime/basement_labels.png',
          regions=[region('landing','楼梯平台',3.4,-3.6,2.42,1.6,[4.5,-2.8]),
                   region('basement_stairs','地下室楼梯',4.65,-2.1,1.1,3.6,[5.2,-.05]),
                   region('examination','医学检查区',-5.35,-5.25,8.62,2,[-1.3,-4.55]),
                   region('laboratory','实验室',-5.35,-3.25,8.62,2.30,[-1.15,-2.45]),
                   region('observation','留观笼舍',-5.35,-.95,8.62,2.10,[-2.35,.72])])
project=lambda p:((p[0]+5.85)/12.2*1023,(p[1]+5.8)/7.9*1023)
base=Image.new('RGB',(1024,1024),'#263d3b');b=ImageDraw.Draw(base)
structure=Image.new('RGBA',(1024,1024));s=ImageDraw.Draw(structure)
def rect(draw,a,bb,color,width=0):
    draw.rectangle([project(a),project(bb)],fill=color if not width else None,outline=color if width else None,width=width)
rect(b,[-5.35,-5.25],[3.40,1.15],'#899e96')
rect(b,[3.4,-3.6],[5.82,-2.0],'#a2b4a2');rect(b,[4.65,-2.1],[5.75,1.5],'#8da599')
for a,bb in [([-5.42,-5.32],[3.34,-5.32]),([-5.42,1.22],[3.34,1.22]),([-5.42,-5.32],[-5.42,1.22]),
             ([3.34,-5.32],[3.34,-3.47]),([3.34,-2.13],[3.34,1.22]),([3.34,-3.65],[5.82,-3.65]),
             ([3.4,-1.94],[4.62,-1.94]),([5.82,-3.65],[5.82,-2.0]),([4.60,-2.1],[4.60,1.5]),([5.80,-2.1],[5.80,1.5])]:
    s.line([project(a),project(bb)],fill='#e7dfc9',width=7)
for x in [-4.2,-2.37,-.54]:
    rect(s,[x-.57,-.59],[x+.57,1.03],'#304a47',3)
    s.line([project([x-.52,-.59]),project([x+.52,-.59])],fill='#ecd3a2',width=4)
# The three-relay door is now at the laboratory portal on the lower landing.
s.line([project([3.34,-3.44]),project([3.34,-2.16])],fill='#ecd3a2',width=5)
rect(s,[-.07,-4.51],[.57,-3.33],'#d3d7c8',4)
rect(s,[-4.95,-5.03],[-2.38,-3.77],'#c3c9ba',3)
rect(s,[2.55,-.58],[3.1,.78],'#c3c9ba',3)
for i in range(19):
    z=1.50-i*.2;s.line([project([4.65,z]),project([5.75,z])],fill='#c9cfba',width=3)
s.line([project([5.2,.95]),project([5.2,-1.60])],fill='#f1d69d',width=6)
s.polygon([project(p) for p in [[5.2,-1.75],[5.07,-1.50],[5.33,-1.50]]],fill='#f1d69d')
labels=Image.new('RGBA',(1024,1024));d=ImageDraw.Draw(labels)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',23)
for r in spec['regions']:d.text(project(r['label_xz']),r['name'],font=font,anchor='mm',fill='#f1ebd8',stroke_width=2,stroke_fill='#263d3b')
for image,key in [(base,'base'),(structure,'structure'),(labels,'labels')]:image.save(MAP/spec[key])
layout['maps']['basement']=spec
path.write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('BASEMENT_MAP_UPDATED')
