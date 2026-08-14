#!/usr/bin/env python3
"""Split the downloaded raw images into train/val/test and write a manifest.

Reads ml/data/raw/<class_id>/*.{jpg,png} (populated by download_dataset.py)
and writes ml/data/manifest.csv with one row per image: relative path, class
id, and assigned split. Stratified per class so rare classes (e.g.
potato_healthy, ~150 images) still get representative val/test coverage.

Doesn't move or copy image files — the manifest is the source of truth for
which split an image belongs to, so re-running with a different seed/ratio
never leaves stale duplicated copies lying around.

Usage:
    python scripts/prepare_dataset.py
    python scripts/prepare_dataset.py --val-ratio 0.15 --test-ratio 0.15 --seed 42
"""

import argparse
import csv
import json
import random
from pathlib import Path

from class_map import CLASS_MAP

ML_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = ML_DIR / "data" / "raw"
MANIFEST_PATH = ML_DIR / "data" / "manifest.csv"
CLASS_NAMES_PATH = ML_DIR / "data" / "class_names.json"

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}


def split_class_images(images: list[Path], val_ratio: float, test_ratio: float, rng: random.Random):
    shuffled = images[:]
    rng.shuffle(shuffled)
    n = len(shuffled)
    n_val = round(n * val_ratio)
    n_test = round(n * test_ratio)
    val = shuffled[:n_val]
    test = shuffled[n_val : n_val + n_test]
    train = shuffled[n_val + n_test :]
    return train, val, test


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--val-ratio", type=float, default=0.15)
    parser.add_argument("--test-ratio", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    class_ids = list(CLASS_MAP.keys())

    rows = []
    class_counts = {}
    for class_id in class_ids:
        class_dir = RAW_DIR / class_id
        if not class_dir.is_dir():
            print(f"  ! skipping {class_id}: {class_dir} not found (run download_dataset.py first)")
            continue

        images = sorted(p for p in class_dir.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES)
        if not images:
            print(f"  ! skipping {class_id}: no images found")
            continue

        train, val, test = split_class_images(images, args.val_ratio, args.test_ratio, rng)
        class_counts[class_id] = {"train": len(train), "val": len(val), "test": len(test)}

        for split_name, split_images in [("train", train), ("val", val), ("test", test)]:
            for img_path in split_images:
                rows.append(
                    {
                        "filepath": str(img_path.relative_to(ML_DIR)),
                        "class_id": class_id,
                        "split": split_name,
                    }
                )

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(MANIFEST_PATH, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["filepath", "class_id", "split"])
        writer.writeheader()
        writer.writerows(rows)

    with open(CLASS_NAMES_PATH, "w") as f:
        json.dump(class_ids, f, indent=2)

    print(f"Wrote {len(rows)} rows to {MANIFEST_PATH}")
    print(f"Wrote {len(class_ids)} class names to {CLASS_NAMES_PATH}\n")
    print(f"{'class_id':<32} {'train':>6} {'val':>6} {'test':>6}")
    for class_id, counts in class_counts.items():
        print(f"{class_id:<32} {counts['train']:>6} {counts['val']:>6} {counts['test']:>6}")


if __name__ == "__main__":
    main()
