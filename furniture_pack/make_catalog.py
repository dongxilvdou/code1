"""Lay out the real Godot renders and their measured dimensions as a contact sheet."""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
decor = '--decor' in sys.argv
items = json.loads((ROOT / ('decor_catalog.json' if decor else 'catalog.json')).read_text(encoding='utf-8'))['items']
font_path = 'C:/Windows/Fonts/msyh.ttc'
font = lambda size: ImageFont.truetype(font_path, size)
rows_count = (len(items)+4)//5
height = 268+rows_count*398
canvas = Image.new('RGB', (2000, height), '#edece4')
draw = ImageDraw.Draw(canvas)
draw.rectangle((0, 0, 2000, 168), fill='#283d32')
draw.text((48, 30), 'CALICO  /  猫屋日记 · '+('生活陈设与设备' if decor else '家具系列'), font=font(43), fill='#f0e9d8')
draw.text((50, 100), f'{len(items)} 件独立模型     暖木 · 米色织物 · 鼠尾草绿     /     尺寸：宽 × 深 × 高（米）', font=font(22), fill='#c8d0be')
for i, item in enumerate(items):
    x = 40 + (i % 5) * 388
    y = 195 + (i // 5) * 398
    render = Image.open(ROOT / 'previews' / 'items' / (item['id'] + '.png')).convert('RGB')
    render = render.resize((372, 233), Image.Resampling.LANCZOS)
    canvas.paste(render, (x, y))
    draw.text((x+8, y+249), f'{i+1:02d}  {item["name"]}', font=font(23), fill='#293f31')
    w, h, d = item['dimensions_m']
    draw.text((x+8, y+289), f'{w:.2f} × {d:.2f} × {h:.2f} m', font=font(21), fill='#5a6857')
    draw.text((x+8, y+326), item['room'], font=font(18), fill='#7b795f')
draw.line((48, height-55, 1952, height-55), fill='#bdc4b5', width=2)
draw.text((48, height-40), '1 Godot 单位 = 1 米  ·  可复用场景资产  ·  已用于两层别墅的室内与花园布置', font=font(21), fill='#52644f')
canvas.save(ROOT / 'previews' / ('catalog_decor.png' if decor else 'catalog.png'))

rows = ['| 家具 | 宽 × 深 × 高（米） | 场景文件 |', '|---|---|---|']
for item in items:
    w, h, d = item['dimensions_m']
    rows.append(f'| {item["name"]} | {w:.2f} × {d:.2f} × {h:.2f} | [打开](scenes/{item["id"]}.tscn) |')
(ROOT / ('陈设尺寸清单.md' if decor else '尺寸清单.md')).write_text('# 家具与陈设尺寸清单\n\n尺寸包含把手、扶手、床头板和龙头等外伸部件。\n\n' + '\n'.join(rows) + '\n', encoding='utf-8')
print(f'CATALOG: {len(items)} assets, contact sheet and dimensions written')
