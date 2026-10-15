"""Original, deterministic procedural surface textures and sound design."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import wave, math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets'
OUT.mkdir(exist_ok=True)
rng = np.random.default_rng(407)
N = 512
def save(name, base, noise=7):
    a = np.asarray(base).astype(float)
    a += rng.normal(0, noise, a.shape[:2])[...,None]
    Image.fromarray(np.uint8(np.clip(a,0,255))).save(OUT / (name+'.png'))

# A restrained continuous plaster grain, rather than painted blotches.
for name, rgb in [('plaster',(158,159,141))]:
    cloud=Image.fromarray(rng.integers(65,195,(32,32),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(12))
    cloud=np.asarray(cloud).astype(float)
    grain=np.asarray(Image.fromarray(rng.integers(90,165,(128,128),dtype=np.uint8)).resize((N,N),Image.Resampling.BILINEAR)).astype(float)
    a=np.empty((N,N,3),float)
    for ch,v in enumerate(rgb):a[:,:,ch]=v+(cloud-128)*.13+(grain-128)*.05
    im=Image.fromarray(np.uint8(np.clip(a,0,255)))
    d=ImageDraw.Draw(im)
    save(name,im,2)

im=Image.new('RGB',(N,N));d=ImageDraw.Draw(im)
for row in range(8):
    y=row*64
    shift=(row%3)*87
    c=tuple(int(v) for v in np.array([110,71,45])+rng.integers(-13,13))
    d.rectangle((0,y,N,y+63),fill=c)
    d.line((0,y,N,y),fill=(39,29,22),width=2)
    for x in range(shift,N,256):d.line((x,y,x,y+64),fill=(42,29,23),width=2)
    for k in range(180):
        x=int(rng.integers(0,N)); yy=y+int(rng.integers(3,61))
        cc=tuple(max(0,min(255,v+int(rng.integers(-16,16)))) for v in c)
        d.line((x,yy,x+int(rng.integers(6,90)),yy+int(rng.integers(-2,3))),fill=cc)
save('wood',im,3)

for name, cols in [('bath_tile',[(184,185,163),(160,178,165)])]:
    im=Image.new('RGB',(N,N),(62,77,70)); d=ImageDraw.Draw(im)
    for y in range(0,N,64):
        for x in range(0,N,64):
            c=tuple(max(0,v+int(rng.integers(-8,8))) for v in cols[(x//64+y//64)%2])
            d.rectangle((x+2,y+2,x+61,y+61),fill=c)
            d.line((x+3,y+3,x+60,y+3),fill=tuple(min(255,v+20) for v in c))
    save(name,im,3)

# Stereo rain bed, a synthesized voiced meow, soft paw taps, and discovery chimes.
SR=22050
def wav(name,data):
    data=np.clip(data,-.95,.95)
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(1 if data.ndim==1 else data.shape[1]);f.setsampwidth(2);f.setframerate(SR)
        f.writeframes((data*32767).astype('<i2').tobytes())
t=np.arange(SR*12)/SR
n=rng.normal(0,1,len(t)); rain=np.convolve(n,np.ones(7)/7,'same')*.075
for i in range(500):
    p=int(rng.integers(0,len(t)-100)); rain[p:p+100]+=rng.uniform(.006,.04)*np.exp(-np.arange(100)/12)
wav('rain',rain)
t=np.arange(int(SR*.75))/SR; freq=520+240*np.sin(np.pi*t/.75)-280*(t/.75)
phase=np.cumsum(freq)*2*np.pi/SR;env=np.sin(np.pi*t/.75)**1.4
voice=(np.sin(phase)+.35*np.sin(phase*2)+.16*np.sin(phase*3))*.22*env
wav('meow',voice)
t=np.arange(int(SR*.11))/SR
wav('paw',rng.normal(0,.04,len(t))*np.exp(-t*65)+.025*np.sin(2*np.pi*170*t)*np.exp(-t*40))
print('Generated current villa textures and three sound assets.')
