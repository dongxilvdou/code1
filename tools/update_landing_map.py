"""Measured stair map for the central circular bed; never redraw other rooms."""
import json, math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];MAP=ROOT/'villa_maps'
p=MAP/'layout.json';layout=json.loads(p.read_text(encoding='utf8'));s=layout['maps']['stairs']
s['regions'][0]['polygon_xz']=[[3.45,-.5],[4.55,-.5],[4.55,1.5],[3.45,1.5]]
s['regions'][1]['polygon_xz']=[[3.45,-2.32],[5.75,-2.32],[5.75,-.5],[3.45,-.5]]
s['regions'][1]['label_xz']=[4.6,-2.1]
s['regions'][2]['polygon_xz']=[[4.65,-.5],[5.75,-.5],[5.75,1.5],[4.65,1.5]]
s['dog_bed']={'center_xz':[4.6,-1.41],'radius_m':.55,'crossing_z':-.71}
p.write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
for size,folder in [(2048,MAP/'assets'),(1024,MAP/'assets/runtime')]:
 x,z,w,d=s['world_rect_xz'];scale=(size-1)/w
 def xy(p):return ((p[0]-x)/w*(size-1),(p[1]-z)/d*(size-1))
 floor=Image.new('RGBA',(size,size),'#263f3d');f=ImageDraw.Draw(floor)
 for r in s['regions']:f.polygon([xy(v) for v in r['polygon_xz']],fill='#8da99b')
 structure=Image.new('RGBA',(size,size));draw=ImageDraw.Draw(structure)
 for wall in s['walls']:
  cursor=wall['start'];spans=[]
  for h in sorted(wall['holes'],key=lambda h:h['a']):spans.append((cursor,h['a']));cursor=h['b']
  spans.append((cursor,wall['end']))
  for a,b in spans:
   if b<=a:continue
   points=[[a,wall['value']],[b,wall['value']]] if wall['axis']=='h' else [[wall['value'],a],[wall['value'],b]]
   draw.line([xy(v) for v in points],fill='#e8dfc5',width=max(2,round(wall['width']*scale)))
 for xmin,xmax in [(3.45,4.55),(4.65,5.75)]:
  for i in range(10):
   zz=-.5+2*i/9
   draw.line([xy((xmin,zz)),xy((xmax,zz))],fill='#607f74',width=max(1,size//650))
 def disk(center,r,fill):
  a=xy((center[0]-r,center[1]-r));b=xy((center[0]+r,center[1]+r));draw.ellipse((*a,*b),fill=fill)
 disk((4.6,-1.41),.55,'#586c59');disk((4.6,-1.41),.45,'#c1b397')
 path=[(4,1.10),(4,-.71),(5.2,-.71),(5.2,1.10)]
 draw.line([xy(v) for v in path],fill='#d9b26d',width=max(2,size//180),joint='curve')
 draw.polygon([xy((5.2,1.21)),xy((5.08,1.0)),xy((5.32,1.0))],fill='#d9b26d')
 labels=Image.new('RGBA',(size,size));ld=ImageDraw.Draw(labels)
 font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',round(size*.020))
 for r in s['regions']:ld.text(xy(r['label_xz']),r['name'],font=font,anchor='mm',fill='#f1ebd8',stroke_width=max(1,size//900),stroke_fill='#263d3b')
 ld.text(xy((4.6,-1.41)),'狗窝',font=font,anchor='mm',fill='#332f24')
 base=Image.alpha_composite(floor,structure)
 for name,img in [('base',base),('structure',structure),('labels',labels)]:img.save(folder/f'stairs_{name}.png')
 if size==2048:
  floor.save(folder/'stairs_floor.png');Image.alpha_composite(base,labels).save(folder/'stairs_labeled.png')
  for r in s['regions']:
   for category,color in [('masks',(255,255,255,255)),('highlights',(225,185,101,100))]:
    im=Image.new('RGBA',(size,size));ImageDraw.Draw(im).polygon([xy(v) for v in r['polygon_xz']],fill=color);im.save(folder/category/f"stairs_{r['id']}.png")
catalog_path=ROOT/'furniture_pack/catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf8'))
for item in catalog['items']:
 if item['id']=='dog_nest':
  item.update(name='圆形软垫狗窝与休息中的大狗嚼',dimensions_m=[1.10,.55,1.10],bounds_min_m=[-.55,.015,-.55],triangles=24060,note='直径 1.10 m 的圆形木底、亚麻软垫与鼠尾草绿围边，置于半层平台中央。犬保持两倍猫的参考尺寸，使用保长关节解算的伏卧动作。')
catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('LANDING_MAP_UPDATED')
