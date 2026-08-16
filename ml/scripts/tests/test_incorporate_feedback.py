"""Exercises the Week 16 retraining-mechanics script (ml/scripts/
incorporate_feedback.py) against small synthetic images — not real
field/pilot photos, which don't exist yet (see
docs/adr/0016-retraining-pipeline-mechanics.md). Proves the merge mechanics
work; says nothing about model quality or real farmer feedback.
"""

import csv

from incorporate_feedback import incorporate
from PIL import Image

CSV_FIELDS = [
    "feedback_id",
    "scan_id",
    "image",
    "predicted_class",
    "confidence",
    "model_version",
    "farmer_notes",
    "feedback_created_at",
    "corrected_class",
]


def _write_csv(path, rows):
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def _make_image(path, color=(10, 20, 30)):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (4, 4), color=color).save(path)


def _row(**overrides):
    row = {field: "" for field in CSV_FIELDS}
    row.update(
        {
            "feedback_id": "fb-1",
            "scan_id": "scan-1",
            "image": "scans/2026/06/leaf.png",
            "predicted_class": "tomato_early_blight",
            "confidence": "0.4",
            "model_version": "v0.1.0",
        }
    )
    row.update(overrides)
    return row


def test_incorporates_a_reviewed_row_into_the_corrected_class_folder(tmp_path):
    images_dir = tmp_path / "images"
    _make_image(images_dir / "leaf.png")
    csv_path = tmp_path / "candidates.csv"
    _write_csv(csv_path, [_row(corrected_class="tomato_late_blight")])
    raw_dir = tmp_path / "raw"

    counts = incorporate(csv_path, images_dir, raw_dir=raw_dir)

    assert counts["incorporated"] == 1
    destination = raw_dir / "tomato_late_blight" / "feedback_fb-1.png"
    assert destination.is_file()


def test_skips_rows_that_have_not_been_reviewed_yet(tmp_path):
    images_dir = tmp_path / "images"
    _make_image(images_dir / "leaf.png")
    csv_path = tmp_path / "candidates.csv"
    _write_csv(csv_path, [_row(corrected_class="")])
    raw_dir = tmp_path / "raw"

    counts = incorporate(csv_path, images_dir, raw_dir=raw_dir)

    assert counts["incorporated"] == 0
    assert counts["skipped_unreviewed"] == 1
    assert not raw_dir.exists()


def test_skips_rows_with_an_unrecognized_corrected_class(tmp_path, capsys):
    images_dir = tmp_path / "images"
    _make_image(images_dir / "leaf.png")
    csv_path = tmp_path / "candidates.csv"
    _write_csv(csv_path, [_row(corrected_class="cotton_rust")])
    raw_dir = tmp_path / "raw"

    counts = incorporate(csv_path, images_dir, raw_dir=raw_dir)

    assert counts["incorporated"] == 0
    assert counts["skipped_invalid_class"] == 1
    assert "not a known class id" in capsys.readouterr().out
    assert not raw_dir.exists()


def test_skips_rows_whose_image_file_is_missing(tmp_path, capsys):
    images_dir = tmp_path / "images"  # no image actually written
    images_dir.mkdir()
    csv_path = tmp_path / "candidates.csv"
    _write_csv(csv_path, [_row(corrected_class="tomato_late_blight")])
    raw_dir = tmp_path / "raw"

    counts = incorporate(csv_path, images_dir, raw_dir=raw_dir)

    assert counts["incorporated"] == 0
    assert counts["skipped_missing_image"] == 1
    assert "image not found" in capsys.readouterr().out


def test_multiple_reviewed_rows_land_in_their_respective_class_folders(tmp_path):
    images_dir = tmp_path / "images"
    _make_image(images_dir / "a.png")
    _make_image(images_dir / "b.png")
    csv_path = tmp_path / "candidates.csv"
    _write_csv(
        csv_path,
        [
            _row(feedback_id="fb-1", image="scans/a.png", corrected_class="potato_early_blight"),
            _row(feedback_id="fb-2", image="scans/b.png", corrected_class="potato_healthy"),
        ],
    )
    raw_dir = tmp_path / "raw"

    counts = incorporate(csv_path, images_dir, raw_dir=raw_dir)

    assert counts["incorporated"] == 2
    assert (raw_dir / "potato_early_blight" / "feedback_fb-1.png").is_file()
    assert (raw_dir / "potato_healthy" / "feedback_fb-2.png").is_file()


def test_rerunning_the_same_csv_overwrites_rather_than_duplicates(tmp_path):
    images_dir = tmp_path / "images"
    _make_image(images_dir / "leaf.png", color=(1, 2, 3))
    csv_path = tmp_path / "candidates.csv"
    _write_csv(csv_path, [_row(corrected_class="tomato_late_blight")])
    raw_dir = tmp_path / "raw"

    incorporate(csv_path, images_dir, raw_dir=raw_dir)
    incorporate(csv_path, images_dir, raw_dir=raw_dir)

    class_dir = raw_dir / "tomato_late_blight"
    assert list(class_dir.iterdir()) == [class_dir / "feedback_fb-1.png"]
