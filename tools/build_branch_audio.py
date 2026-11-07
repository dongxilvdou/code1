"""Deterministic paper handling and device-start sound for the transfer log."""
from pathlib import Path
import math
import random
import struct
import wave

def main():
    target = Path(__file__).resolve().parents[1] / "story_branches/audio/transfer_log.wav"
    target.parent.mkdir(parents=True, exist_ok=True)
    rate = 22050
    noise = random.Random(31)
    data = bytearray()
    for i in range(rate * 3):
        t = i / rate
        rustle = noise.uniform(-1, 1) * max(0, 1 - t / .65) ** 2 * .20
        pulse = 0.0
        if t > 1.0:
            elapsed = t - 1.0
            pulse = (math.sin(elapsed * math.tau * 96) + .3 * math.sin(elapsed * math.tau * 193))
            pulse *= min(1, elapsed * 7) * max(0, 1 - elapsed / 2) * .12
        data.extend(struct.pack("<h", int(max(-1, min(1, rustle + pulse)) * 32767)))
    with wave.open(str(target), "wb") as output:
        output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        output.writeframes(data)

if __name__ == "__main__":
    main()
