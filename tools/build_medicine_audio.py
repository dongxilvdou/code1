"""Original pill-bottle foley: three equal shakes, contrasting pill counts and levels."""
from pathlib import Path
import json
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
COUNTS = [8, 2, 7, 1, 9, 3, 8]
SR = 44100
SECONDS = 2.2


def build_clip(index, count):
    rng = np.random.default_rng(5270 + index)
    audio = np.zeros(round(SR * SECONDS), dtype=np.float64)
    amplitude = .15 + .038 * count
    for shake, start in enumerate([.15, .83, 1.51]):
        spacing = .14 if count == 2 else .105 if count == 3 else .29 / max(1, count - 1)
        for pill in range(count):
            offset = 0 if pill == 0 else float(rng.uniform(-.004, .004))
            onset = start + pill * spacing + offset
            t = np.arange(round(SR * .105)) / SR
            # Short non-periodic tablet clicks, with a damped glass/plastic shell.
            noise = rng.standard_normal(t.size)
            noise -= np.roll(noise, 1) * .72
            noise /= max(1, np.max(np.abs(noise)))
            frequency = 1050 + index * 35 + float(rng.uniform(-100, 100))
            shell = (.38 * np.sin(math.tau * frequency * t) * np.exp(-t / .013)
                     + .20 * np.sin(math.tau * frequency * 2.31 * t) * np.exp(-t / .008)
                     + .12 * np.sin(math.tau * frequency * .57 * t) * np.exp(-t / .022))
            attack = 1 - np.exp(-t / .00065)
            tick = attack * (shell + .65 * noise * np.exp(-t / .010))
            gain = amplitude * (1 - .05 * shake) * float(rng.uniform(.85, 1.1))
            begin = round(onset * SR)
            audio[begin:begin + t.size] += tick * gain
        if count >= 7:
            # Dense bottles have a short rolling collision tail, absent in low doses.
            t = np.arange(round(SR * .34)) / SR
            rolling = rng.standard_normal(t.size)
            rolling = np.convolve(rolling, np.ones(5) / 5, mode="same")
            envelope = np.sin(np.pi * np.clip(t / .34, 0, 1)) ** 1.5
            begin = round((start + .015) * SR)
            audio[begin:begin + t.size] += rolling * envelope * .008 * count
    return audio


def main():
    output = ROOT / "act3/audio"
    clips = [build_clip(i, n) for i, n in enumerate(COUNTS)]
    # One common gain preserves the perceptual differences; never normalize per bottle.
    common_gain = .78 / max(float(np.max(np.abs(clip))) for clip in clips)
    report = []
    for index, (count, clip) in enumerate(zip(COUNTS, clips)):
        clip *= common_gain
        with wave.open(str(output / f"bottle_{index}.wav"), "wb") as stream:
            stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(SR)
            stream.writeframes(np.round(clip * 32767).astype("<i2").tobytes())
        report.append({"bottle": index + 1, "pills": count, "shakes": 3,
                       "impacts": count * 3, "seconds": SECONDS,
                       "rms_db": round(20 * math.log10(float(np.sqrt(np.mean(clip ** 2)))) , 2),
                       "peak_db": round(20 * math.log10(float(np.max(np.abs(clip)))), 2)})
    low = [entry["rms_db"] for entry in report if entry["pills"] <= 3]
    full = [entry["rms_db"] for entry in report if entry["pills"] >= 7]
    assert min(full) - max(low) >= 5, "The quietest full bottle must clearly exceed the loudest low-dose bottle."
    assert sorted(range(7), key=lambda i: report[i]["rms_db"])[:3] == [3, 1, 5]
    diagnostic = ROOT / "logs/medicine_audio"
    diagnostic.mkdir(parents=True, exist_ok=True)
    (diagnostic / "levels.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
