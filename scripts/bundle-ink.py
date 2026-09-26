#!/usr/bin/env python3
"""Bundle a reviewed simulator ink recording: bundle-ink.py /path/to/ink-ID."""
import argparse
import json
import pathlib
import shutil
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("recording", type=pathlib.Path)
args = parser.parse_args()
sidecars = list(args.recording.glob("*.ink.json"))
if len(sidecars) != 1:
    sys.exit("Choose a recording folder containing exactly one .ink.json sidecar.")
sidecar = sidecars[0]
asset = json.loads(sidecar.read_text())
if asset.get("verified") is not True:
    sys.exit("Review every checkpoint's lines and token boxes, then set verified to true.")
if not asset.get("checkpoints"):
    sys.exit("Ground-truth checkpoints are required; empty OCR output is not ground truth.")
filename = asset.get("file", "")
if pathlib.Path(filename).name != filename or not (args.recording / filename).is_file():
    sys.exit("The sidecar must name a local drawing or photo in the recording folder.")
def box_valid(box):
    values = [box.get(k) for k in ("x", "y", "w", "h")]
    return all(isinstance(v, (float, int)) for v in values) and 0 <= box["x"] < 1 and 0 <= box["y"] < 1 and box["w"] > 0 and box["h"] > 0 and box["x"] + box["w"] <= 1.001 and box["y"] + box["h"] <= 1.001
for checkpoint in asset["checkpoints"]:
    for line in checkpoint["lines"]:
        if not line["text"].strip() or not box_valid(line["box"]):
            sys.exit("Each line needs text and a valid page-normalized box.")
        if not line.get("tokens"):
            sys.exit("Each line needs reviewed token boxes.")
        if any(not box_valid(t["box"]) for t in line["tokens"]):
            sys.exit("A token box falls outside the normalized page.")
        line["confidence"] = 1.0
destination = pathlib.Path(__file__).resolve().parent.parent / "App/Resources/InkDemos"
destination.mkdir(parents=True, exist_ok=True)
for name in (sidecar.name, filename):
    if (destination / name).exists():
        sys.exit(f"Already bundled: {name}. Rename the recording to keep both versions.")
shutil.copy2(args.recording / filename, destination / filename)
(destination / sidecar.name).write_text(json.dumps(asset, indent=2) + "\n")
print(f"Bundled {asset['title']}. Rebuild Burrow to include the recording.")
