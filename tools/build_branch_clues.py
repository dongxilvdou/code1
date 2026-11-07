"""Update typography only; retain the original photographic assets and faces."""
from pathlib import Path
import ast
import re
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DATA = (ROOT / 'story_branches/data.gd').read_text(encoding='utf-8')
OUT = ROOT / 'story_branches/art/clues'
FONT = Path('C:/Windows/Fonts/msyh.ttc')

def copy(key):
    return ast.literal_eval(re.search(r'^const '+key+r' := (".*")$', DATA, re.M).group(1))

def centered(draw, line, y, size, width, fill='#43554b'):
    font = ImageFont.truetype(str(FONT), size)
    box = draw.textbbox((0, 0), line, font=font)
    draw.text(((width - box[2]) / 2, y), line, font=font, fill=fill)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Keep the existing memo's paper, tape, margins and UV dimensions.
    memo_path = ROOT / 'act3/textures/password_note.png'
    memo = Image.open(memo_path).convert('RGB')
    d = ImageDraw.Draw(memo)
    d.rectangle((65, 205, 705, 955), fill=memo.getpixel((64, 170)))
    text = copy('PASSWORD_NOTE')
    centered(d, text[:5], 280, 100, 768)
    centered(d, text[5:], 425, 100, 768)
    d.line((95, 600, 675, 600), fill='#9a987a', width=3)
    memo.save(memo_path)
    # New copies replace captions only. Original photos stay untouched.
    for source, target, caption, y_ratio in [
        ('act2/memory_photo.png', 'memory_photo.png', copy('PHOTO_NAME')+'\n'+copy('PHOTO_BACK').split('\n')[-1], .831),
        ('act3/textures/lab_photo.png', 'lab_photo.png', copy('LAB_PHOTO'), .91),
    ]:
        image = Image.open(ROOT / source).convert('RGB')
        width, height = image.size
        y = int(height * y_ratio)
        if target == 'memory_photo.png':
            d = ImageDraw.Draw(image)
            d.rectangle((35, y, width-36, height-22), fill='#eee5d3')
            centered(d, copy('PHOTO_NAME'), y+6, 45, width)
            centered(d, copy('PHOTO_BACK').split('\n')[-1], y+69, 31, width)
        else:
            d = ImageDraw.Draw(image)
            centered(d, caption, y+7, 35, width)
        image.save(OUT / target)
    footer = copy('TIME_FOOTER')
    for name in ['hour', 'minute', 'second']:
        path = ROOT / f'furniture_pack/quest_props/clock_{name}_note.svg'
        svg = path.read_text(encoding='utf-8')
        svg = svg.replace('时间纸条 · 只记录一根指针', footer)
        if footer not in svg:
            svg = svg.replace('</svg>', f'<text x="256" y="330" font-family="Microsoft YaHei, sans-serif" font-size="18" text-anchor="middle" fill="#746953">{footer}</text>\n</svg>')
        path.write_text(svg, encoding='utf-8')

if __name__ == '__main__':
    main()
