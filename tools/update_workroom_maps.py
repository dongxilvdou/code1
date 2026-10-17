"""Regenerate code-native map label layers and a measured basement plan."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];MAP=ROOT/'villa_maps';path=MAP/'layout.json'
layout=json.loads(path.read_text(encoding='utf8'));maps=layout['maps']
for key,region_id,name in [('floor_1','guest','工作书房'),('floor_2','bedroom_b','电脑房')]:
    for r in maps[key]['regions']:
        if r['id']==region_id:r['name']=name
for wall in maps['floor_1']['walls']:
    if wall['source_name']=='StairEntrance':
        if not any(abs(h['a']-4.65)<.01 for h in wall['holes']):wall['holes'].append({'a':4.65,'b':5.75,'kind':'arch'})
maps['basement']={'id':'basement','name':'地下层','world_rect_xz':[3.1,-4.0,3.2,6.1],'pixel_size':[1024,1024],
 'base':'assets/runtime/basement_base.png','structure':'assets/runtime/basement_structure.png','labels':'assets/runtime/basement_labels.png',
 'regions':[{'id':'landing','name':'下层平台','polygon_xz':[[3.4,-3.6],[5.82,-3.6],[5.82,-2.0],[3.4,-2.0]],'label_xz':[4.45,-2.80]},
 {'id':'basement_stairs','name':'地下室楼梯','polygon_xz':[[4.65,-2.1],[5.75,-2.1],[5.75,1.5],[4.65,1.5]],'label_xz':[5.2,-.1]}]}
font_path='C:/Windows/Fonts/msyh.ttc'
def projection(spec,size):
    x,z,w,d=spec['world_rect_xz']
    return lambda p:((p[0]-x)/w*(size-1),(p[1]-z)/d*(size-1))
def labels(spec,size,target):
    image=Image.new('RGBA',(size,size));draw=ImageDraw.Draw(image);project=projection(spec,size)
    font=ImageFont.truetype(font_path,round(size*(.030 if spec['id']=='basement' else .020)))
    for r in spec['regions']:
        if 'label_xz' not in r:continue
        draw.text(project(r['label_xz']),r['name'],font=font,anchor='mm',fill='#f1ebd8',stroke_width=max(1,size//900),stroke_fill='#263d3b')
    if spec['id']=='floor_1':draw.text(project([5.2,1.9]),'B1 ↓',font=font,anchor='mm',fill='#f1d69d',stroke_width=1,stroke_fill='#263d3b')
    image.save(target)
for key in ['floor_1','floor_2']:
    spec=maps[key]
    for folder,size in [(MAP/'assets',2048),(MAP/'assets/runtime',1024)]:
        existing=folder/(key+'_labels.png')
        # The complete layer is regenerated from world-space room data, not patched pixels.
        labels(spec,size,existing)
        if key=='floor_1':
            image=Image.new('RGBA',(size,size));draw=ImageDraw.Draw(image);project=projection(spec,size)
            for wall in spec['walls']:
                cursor=wall['start'];spans=[]
                for hole in sorted(wall['holes'],key=lambda h:h['a']):
                    spans.append((cursor,hole['a']));cursor=hole['b']
                    if hole['kind']=='window':
                        points=[[hole['a'],wall['value']],[hole['b'],wall['value']]] if wall['axis']=='h' else [[wall['value'],hole['a']],[wall['value'],hole['b']]]
                        draw.line([project(p) for p in points],fill='#8eb9af',width=max(2,size//300))
                spans.append((cursor,wall['end']))
                for a,b in spans:
                    if b<=a:continue
                    half=wall['width']/2
                    points=[[a,wall['value']-half],[b,wall['value']+half]] if wall['axis']=='h' else [[wall['value']-half,a],[wall['value']+half,b]]
                    draw.rectangle([project(p) for p in points],fill='#e4dac2')
            image.save(folder/(key+'_structure.png'))
spec=maps['basement'];size=1024;project=projection(spec,size)
base=Image.new('RGB',(size,size),'#263d3b');b=ImageDraw.Draw(base)
structure=Image.new('RGBA',(size,size));s=ImageDraw.Draw(structure)
for r in spec['regions']:
    polygon=[project(p) for p in r['polygon_xz']];b.polygon(polygon,fill='#879f93');s.line(polygon+[polygon[0]],fill='#e8dec3',width=7)
for i in range(19):
    z=1.50-i*.2
    s.line([project([4.65,z]),project([5.75,z])],fill='#d4ceb5',width=3)
s.line([project([5.2,.95]),project([5.2,-1.60])],fill='#f1d69d',width=7)
s.polygon([project(p) for p in [[5.2,-1.75],[5.07,-1.50],[5.33,-1.50]]],fill='#f1d69d')
base.save(MAP/spec['base']);structure.save(MAP/spec['structure']);labels(spec,size,MAP/spec['labels'])
path.write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('MAP_UPDATE floor labels, preserved room IDs, and basement layers')
