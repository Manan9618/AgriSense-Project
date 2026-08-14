#!/usr/bin/env python3
"""Fetch a class-scoped subset of the PlantVillage dataset.

Uses a partial + sparse git clone so we only ever download the ~10 class
folders we actually target (docs/classes.md), not the full ~2GB repo. Safe to
re-run: already-populated class directories are left alone unless --force is
passed.

Usage:
    python scripts/download_dataset.py
    python scripts/download_dataset.py --classes potato_healthy,tomato_healthy
    python scripts/download_dataset.py --limit-per-class 200
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from class_map import CLASS_MAP

DATASET_REPO = "https://github.com/spMohanty/PlantVillage-Dataset.git"
DATASET_SUBDIR = "raw/color"  # real-world-style RGB photos, not segmented/grayscale variants

ML_DIR = Path(__file__).resolve().parent.parent
CACHE_DIR = ML_DIR / "data" / ".cache" / "PlantVillage-Dataset"
OUTPUT_DIR = ML_DIR / "data" / "raw"

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}


def sparse_clone(folders: list[str]) -> None:
    sparse_paths = [f"{DATASET_SUBDIR}/{folder}" for folder in folders]

    if not CACHE_DIR.exists():
        print(f"Cloning {DATASET_REPO} (partial + sparse)...")
        CACHE_DIR.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "git",
                "clone",
                "--filter=blob:none",
                "--depth=1",
                "--sparse",
                DATASET_REPO,
                str(CACHE_DIR),
            ],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(CACHE_DIR), "sparse-checkout", "init", "--cone"], check=True
        )

    print(f"Setting sparse-checkout to {len(sparse_paths)} class folder(s)...")
    subprocess.run(
        ["git", "-C", str(CACHE_DIR), "sparse-checkout", "set", *sparse_paths],
        check=True,
    )


def copy_class(class_id: str, folder: str, limit: int | None, force: bool) -> int:
    src = CACHE_DIR / DATASET_SUBDIR / folder
    dest = OUTPUT_DIR / class_id

    if not src.is_dir():
        print(f"  ! source folder not found for {class_id}: {src}", file=sys.stderr)
        return 0

    if dest.exists() and any(dest.iterdir()) and not force:
        count = sum(1 for p in dest.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES)
        print(f"  = {class_id}: already have {count} images, skipping (use --force to redo)")
        return count

    dest.mkdir(parents=True, exist_ok=True)
    images = sorted(p for p in src.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES)
    if limit is not None:
        images = images[:limit]

    for img in images:
        shutil.copy2(img, dest / img.name)

    print(f"  + {class_id}: copied {len(images)} images")
    return len(images)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--classes",
        help="Comma-separated class IDs to fetch (default: all in class_map.py)",
        default=None,
    )
    parser.add_argument(
        "--limit-per-class",
        type=int,
        default=None,
        help="Cap images copied per class (default: no cap)",
    )
    parser.add_argument(
        "--force", action="store_true", help="Re-copy even if the class folder is already populated"
    )
    args = parser.parse_args()

    class_ids = args.classes.split(",") if args.classes else list(CLASS_MAP.keys())
    unknown = set(class_ids) - set(CLASS_MAP.keys())
    if unknown:
        parser.error(f"Unknown class id(s): {', '.join(sorted(unknown))}")

    folders = [CLASS_MAP[c] for c in class_ids]
    sparse_clone(folders)

    print(f"\nCopying into {OUTPUT_DIR}/<class_id>/...")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    totals = {}
    for class_id in class_ids:
        totals[class_id] = copy_class(
            class_id, CLASS_MAP[class_id], args.limit_per_class, args.force
        )

    print("\nDone.")
    for class_id, count in totals.items():
        print(f"  {class_id}: {count}")
    print(f"  TOTAL: {sum(totals.values())}")


if __name__ == "__main__":
    main()
