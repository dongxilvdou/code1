"""Reproduce the six-second game clip; the source MP4 is never modified."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path(r"C:\zGoDot\3D\UP主必备爆款绿幕素材包，200+猫猫meme动态素材\【高清无水印】大狗大狗叫叫叫meme绿幕素材30秒循环.mp4")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    args = parser.parse_args()
    if not args.ffmpeg or not args.source.is_file():
        parser.error("Provide an existing source MP4 and --ffmpeg path.")
    target = ROOT / "assets/easter_eggs/dog_secret"
    target.mkdir(parents=True, exist_ok=True)
    output = target / "dog_power.ogv"
    subprocess.run([
        args.ffmpeg, "-hide_banner", "-loglevel", "warning", "-i", str(args.source),
        "-t", "6", "-map", "0:v:0", "-map", "0:a:0",
        "-vf", "scale=960:540:flags=lanczos,setsar=1", "-r", "30",
        "-c:v", "libtheora", "-q:v", "7", "-g:v", "64", "-pix_fmt", "yuv420p",
        "-c:a", "libvorbis", "-q:a", "5",
        "-af", "volume=1.4,alimiter=limit=0.95:level=false",
        "-map_metadata", "-1", "-y", str(output),
    ], check=True)
    metadata = {
        "source": str(args.source),
        "source_sha256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
        "output": "dog_power.ogv", "seconds": 6, "width": 960, "height": 540,
        "fps": 30, "audio_gain": 1.4, "audio_limiter": 0.95,
        "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "chroma_key": "Runtime spatial shader; source green is retained only in the encoded clip.",
    }
    (target / "media.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"Created {output} ({output.stat().st_size:,} bytes)")

if __name__ == "__main__":
    main()
