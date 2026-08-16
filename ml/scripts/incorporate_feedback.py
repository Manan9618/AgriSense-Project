#!/usr/bin/env python3
"""Merge human-reviewed, feedback-flagged scans into the training dataset.

Week 16 (Mid-Pilot Iteration) closes the loop the Week 12 retraining
pipeline started: backend/core/management/commands/export_retraining_
candidates.py exports scans whose farmer feedback flagged the diagnosis as
incorrect, with a blank `corrected_class` column for a human to fill in
after actually looking at the image. This script takes that reviewed CSV
plus the corresponding image files (copied out of the Django backend's
MEDIA_ROOT by whoever did the review — ml/ has no direct access to the
backend's media storage) and copies each reviewed image into
ml/data/raw/<corrected_class>/, the exact layout
ml/scripts/prepare_dataset.py already expects.

Rows with a blank `corrected_class` (not yet reviewed) are skipped, not
guessed at. See docs/adr/0016-retraining-pipeline-mechanics.md for why this
script's job stops here — actually re-running train.py on the result is a
separate, deliberate step for once there's enough reviewed field data to be
worth a retrain, not something this script does automatically.

Usage:
    python scripts/incorporate_feedback.py --csv reviewed_candidates.csv --images-dir /path/to/copied/scans
"""

import argparse
import csv
import shutil
from pathlib import Path

from class_map import CLASS_MAP

ML_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = ML_DIR / "data" / "raw"


def incorporate(csv_path: Path, images_dir: Path, raw_dir: Path = RAW_DIR) -> dict[str, int]:
    """Copies each reviewed row's image into raw_dir/<corrected_class>/,
    returns counts by outcome (incorporated / skipped_unreviewed /
    skipped_invalid_class / skipped_missing_image)."""
    counts = {
        "incorporated": 0,
        "skipped_unreviewed": 0,
        "skipped_invalid_class": 0,
        "skipped_missing_image": 0,
    }

    with csv_path.open(newline="") as f:
        for row in csv.DictReader(f):
            corrected_class = row["corrected_class"].strip()
            if not corrected_class:
                counts["skipped_unreviewed"] += 1
                continue

            if corrected_class not in CLASS_MAP:
                print(
                    f"  ! feedback {row['feedback_id']}: '{corrected_class}' is not a known "
                    f"class id, skipping"
                )
                counts["skipped_invalid_class"] += 1
                continue

            source_image = images_dir / Path(row["image"]).name
            if not source_image.is_file():
                print(f"  ! feedback {row['feedback_id']}: image not found at {source_image}")
                counts["skipped_missing_image"] += 1
                continue

            class_dir = raw_dir / corrected_class
            class_dir.mkdir(parents=True, exist_ok=True)
            destination = class_dir / f"feedback_{row['feedback_id']}{source_image.suffix}"
            shutil.copyfile(source_image, destination)
            counts["incorporated"] += 1

    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", required=True, help="Human-reviewed retraining-candidates CSV")
    parser.add_argument(
        "--images-dir",
        required=True,
        help="Directory containing the scan images the CSV's `image` column names",
    )
    args = parser.parse_args()

    counts = incorporate(Path(args.csv), Path(args.images_dir))

    print(f"Incorporated {counts['incorporated']} image(s) into {RAW_DIR}")
    print(f"Skipped {counts['skipped_unreviewed']} not-yet-reviewed row(s)")
    print(f"Skipped {counts['skipped_invalid_class']} row(s) with an unrecognized class")
    print(f"Skipped {counts['skipped_missing_image']} row(s) with a missing image file")
    if counts["incorporated"]:
        print(
            "\nNext step (not run automatically — see docs/adr/0016-retraining-pipeline-"
            "mechanics.md): re-run prepare_dataset.py to fold these into the manifest, then "
            "review whether there's enough new data to justify a retrain."
        )


if __name__ == "__main__":
    main()
