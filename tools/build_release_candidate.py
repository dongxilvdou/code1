"""Copy a reproducible game candidate without editor caches or player saves."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output == source or source in output.parents:
        parser.error("Candidate must be in a separate directory outside the source project")
    output.mkdir(parents=True, exist_ok=True)
    excluded = {".godot", ".git", ".codex", ".agents", "docs", "每周报告汇总", "logs", "screenshots", "__pycache__"}
    files = []
    for path in sorted(source.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(source)
        if any(part in excluded for part in relative.parts) or path.suffix in {".log", ".tmp", ".pyc", ".docx"}:
            continue
        content = path.read_bytes()
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_bytes() != content:
            shutil.copy2(path, target)
        files.append({"path": relative.as_posix(), "size": len(content), "sha256": hashlib.sha256(content).hexdigest()})
    manifest = {"source": str(source), "candidate": str(output), "files": files}
    encoded = json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8")
    (output.parent / "candidate_manifest.json").write_bytes(encoded)
    print(json.dumps({"candidate": str(output), "files": len(files), "manifest_sha256": hashlib.sha256(encoded).hexdigest()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
