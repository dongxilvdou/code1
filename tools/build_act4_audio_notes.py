"""Small original synthetic squeak bursts and three independent clock clue cards."""
from pathlib import Path
import math, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'act4/audio';out.mkdir(exist_ok=True)
for variant in range(3):
    sr=44100;audio=np.zeros(int(sr*1.10),dtype=np.float64);rng=np.random.default_rng(170+variant)
    for i in range(3+variant%2):
        duration=.074+i*.009;start=.07+i*.23+variant*.012
        t=np.arange(int(sr*duration))/sr;u=t/duration
        f0=2300+variant*280+i*180
        pitch=f0+900*np.sin(u*math.pi)+350*np.sin(u*math.tau*1.5)
        phase=np.cumsum(pitch)*math.tau/sr
        envelope=np.sin(u*math.pi)**1.8
        chirp=(np.sin(phase)+.19*np.sin(phase*2.01)+.055*rng.normal(size=t.size))*envelope*(.80+.2*np.sin(t*math.tau*73))*.34
        a=int(start*sr);audio[a:a+len(chirp)]+=chirp
    with wave.open(str(out/('mouse_squeak_%d.wav'%variant)),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
for part,title,value,color in [('hour','小时 / 时针','03','#967448'),('minute','分钟 / 分针','42','#5d7b72'),('second','秒 / 秒针','00','#a5674f')]:
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="360" viewBox="0 0 512 360">
<rect width="512" height="360" fill="#d8cbae"/><path d="M18 25H494V333H18Z" fill="#e5d9bf" stroke="#b6a587" stroke-width="2"/>
<path d="M40 105H472M40 270H472" stroke="#b6aa8d" stroke-width="2"/>
<text x="256" y="80" font-family="Microsoft YaHei, sans-serif" font-size="30" text-anchor="middle" fill="#514f42">{title}</text>
<text x="256" y="246" font-family="Georgia,serif" font-size="150" text-anchor="middle" fill="{color}">{value}</text>
<text x="256" y="309" font-family="Microsoft YaHei, sans-serif" font-size="19" text-anchor="middle" fill="#746953">时间纸条 · 只记录一根指针</text>
<path d="M403 328L482 280" stroke="#c2b398" stroke-width="3"/>
</svg>'''
    (ROOT/'furniture_pack/quest_props'/('clock_%s_note.svg'%part)).write_text(svg,encoding='utf-8')
print('Created 3 synthetic squeak variations and 3 separate clock notes.')
