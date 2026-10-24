"""Rebuild the six-second cat clip without changing the original MP4."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path(r"C:\zGoDot\3D\UP主必备爆款绿幕素材包，200+猫猫meme动态素材\猫猫meme绿幕【1】\臭猫摇晃（有声）.mp4")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    args = parser.parse_args()
    if not args.ffmpeg or not args.source.is_file():
        parser.error("Provide an existing source MP4 and --ffmpeg path.")
    target = ROOT / "assets/easter_eggs/bedroom_secret"
    target.mkdir(parents=True, exist_ok=True)
    output = target / "cat_sway.ogv"
    subprocess.run([
        args.ffmpeg, "-hide_banner", "-loglevel", "warning", "-i", str(args.source),
        "-t", "6", "-map", "0:v:0", "-map", "0:a:0",
        "-vf", "crop=1760:1320:976:320,scale=768:576:flags=lanczos,setsar=1",
        "-r", "30", "-c:v", "libtheora", "-q:v", "7", "-g:v", "64",
        "-pix_fmt", "yuv420p", "-c:a", "libvorbis", "-q:a", "5",
        "-af", "volume=1.4,alimiter=limit=0.95:level=false",
        "-map_metadata", "-1", "-y", str(output),
    ], check=True)
    metadata = {
        "source": str(args.source),
        "source_sha256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
        "output": "cat_sway.ogv", "seconds": 6, "width": 768, "height": 576,
        "fps": 30, "audio_gain": 1.4, "audio_limiter": 0.95,
        "crop_source_pixels": [976, 320, 1760, 1320],
        "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "chroma_key": "Runtime spatial shader; green is removed when rendered above the bed.",
    }
    (target / "media.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Created {output} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
