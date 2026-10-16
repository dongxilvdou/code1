"""Deterministic, seamless material data. R=albedo variation, G=height, B=roughness.

No photographic dependencies. Shared furniture textures stay inside furniture_pack.
Maps are linear data, sampled with mipmaps/anisotropy by the Godot shaders.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "furniture_pack" / "textures"
OUT.mkdir(exist_ok=True)
N = 1024
y, x = np.mgrid[:N, :N].astype(np.float32) / N
rng = np.random.default_rng(1447)


def noise(bands=6):
    result = np.zeros_like(x)
    for i in range(bands):
        freq = 2 ** i
        for _ in range(4):
            a, b = rng.integers(-freq, freq + 1, size=2)
            result += np.sin(2*np.pi*(a*x+b*y)+rng.random()*2*np.pi) / (2**(i*.65)*4)
    return result


def save(name, variation, height, rough):
    channels = np.stack([variation+np.zeros_like(x), height+np.zeros_like(x), rough+np.zeros_like(x)], axis=-1)
    Image.fromarray(np.uint8(np.clip(channels, 0, 1)*255)).save(OUT / (name+".png"))


broad = noise()
fine = rng.normal(0, .025, x.shape).astype(np.float32)
warp = .022*np.sin(y*2*np.pi)+.009*np.sin(y*6*np.pi+x*4*np.pi)
grain = np.sin((x+warp)*2*np.pi*49)
pore = np.maximum(0, np.sin((x+warp)*2*np.pi*121))**12
wood = .53+.10*broad+.030*grain-.06*pore+fine*.5
save("oak_grain", wood, .5+.045*grain-.10*pore, .70+.06*broad+.04*pore)

# Six staggered planks per tile; subtle end grain and knots, never a drawn grid.
row = np.floor(x*6)
across = np.mod(x*6, 1)
along = np.mod(y*2+row*.5, 1)
edge = np.minimum(across, 1-across)
end = np.minimum(along, 1-along)
joint = np.minimum(np.clip(edge/.012, 0, 1), np.clip(end/.0035, 0, 1))
board = .075*np.sin(row*7.13+np.floor(y*2+row*.5)*3.8)
knot = np.zeros_like(x)
for cx, cy in [(.08,.24),(.43,.65),(.73,.31),(.92,.82)]:
    dx = np.minimum(abs(x-cx), 1-abs(x-cx))
    dy = np.minimum(abs(y-cy), 1-abs(y-cy))
    d = (dx/.019)**2+(dy/.036)**2
    knot += np.exp(-d*1.4)*.19+np.exp(-d*.3)*np.sin(d*8)*.025
save("oak_planks", (wood+board-knot)*(.60+.40*joint), .18+.52*joint+.05*grain, .69+.08*broad+.12*(1-joint))

# Woven linen: interlaced threads and irregular slubs, filtered at a distance.
tx, ty = np.sin(x*2*np.pi*64), np.sin(y*2*np.pi*64)
weave = .5+.19*tx+.19*ty+.08*tx*ty
save("linen_weave", .52+.10*tx+.10*ty+.075*broad+fine, weave, .89+.045*tx*ty)
save("plaster_detail", .50+.022*broad+fine*.3, .5+.05*broad+fine*.65, .89+.025*broad)

# Small mineral chips for worktops and the utility/kitchen floors.
canvas = Image.new("L", (N, N), 132)
draw = ImageDraw.Draw(canvas)
for _ in range(4400):
    px, py = rng.integers(0, N, 2)
    radius = int(rng.choice([1,2,3,4,6,9], p=[.15,.23,.27,.20,.10,.05]))
    shade = int(rng.choice([72,97,115,157,178,199]))
    verts = [(int(px+np.cos(a)*radius), int(py+np.sin(a)*radius*.7)) for a in np.linspace(0, 2*np.pi, 6)[:-1]]
    for ox in [-N,0,N]:
        for oy in [-N,0,N]:
            draw.polygon([(a+ox,b+oy) for a,b in verts], fill=shade)
chips = np.asarray(canvas).astype(np.float32)/255
save("mineral_detail", chips+.04*broad, .5+.07*broad+fine*.35, .64+.16*(chips-.5))
# Retain Godot's import IDs; force mipmaps for low cat-eye/grazing-angle views.
for path in OUT.glob("*.png.import"):
    text = path.read_text(encoding="utf-8")
    text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
    text = text.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
    path.write_text(text, encoding="utf-8")
print("SURFACE_TEXTURES: 5 seamless 1024 px packed material maps")
