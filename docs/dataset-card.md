# Dataset Card — v1 (Week 1)

## Source
[PlantVillage-Dataset](https://github.com/spMohanty/PlantVillage-Dataset) (`raw/color` subset),
via `ml/scripts/download_dataset.py`. Public, lab-captured leaf images, one leaf per image on a
uniform background — not field-collected. Field photos are added starting Week 13-16 (pilot).

## Scope
10 classes across Potato, Pepper (bell), Tomato. Rationale in `docs/classes.md` and
`docs/adr/0002-class-list-scope.md`.

## Counts (fetched 2026-08-14)

| class_id | total | train | val | test |
|---|---|---|---|---|
| potato_early_blight | 1000 | 700 | 150 | 150 |
| potato_late_blight | 1000 | 700 | 150 | 150 |
| potato_healthy | 152 | 106 | 23 | 23 |
| pepper_bell_bacterial_spot | 997 | 697 | 150 | 150 |
| pepper_bell_healthy | 1478 | 1034 | 222 | 222 |
| tomato_bacterial_spot | 2127 | 1489 | 319 | 319 |
| tomato_early_blight | 1000 | 700 | 150 | 150 |
| tomato_late_blight | 1909 | 1337 | 286 | 286 |
| tomato_leaf_mold | 952 | 666 | 143 | 143 |
| tomato_healthy | 1591 | 1113 | 239 | 239 |
| **TOTAL** | **12,206** | **8,542** | **1,832** | **1,832** |

Split is stratified per class (70/15/15, seed 42), recorded in `ml/data/manifest.csv` — the
manifest is the source of truth for split membership, not the directory layout, so re-splitting
never requires moving files.

## Known class imbalance

`potato_healthy` (152 images) is ~14x smaller than `tomato_bacterial_spot` (2,127 images). This
is the real-world imbalance Week 2's learning objective ("Handling class imbalance ... with
augmentation") is meant to address — not something to fix at the sourcing stage by discarding
data from the larger classes.

## Known limitations (carry into the Week 22 field-vs-lab evaluation)

- Uniform lab backgrounds, single leaf per frame, consistent lighting — doesn't reflect a
  farmer's phone photo (cluttered background, variable lighting/angle, partial occlusion). This
  is exactly why Section 11.2 of the project plan calls out real-world image variance as a hard
  technical challenge; Week 2 augmentation and the Week 13-16 pilot's field images are the
  mitigations, not this dataset alone.
- No Cotton or Wheat classes (see ADR 0002) — a gap if the pilot region turns out to favor those
  crops.

## Regenerating

```bash
cd ml
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python scripts/download_dataset.py     # ~220MB, populates data/raw/<class_id>/
python scripts/prepare_dataset.py      # writes data/manifest.csv + data/class_names.json
```

Nothing under `ml/data/` is committed to git (see `.gitignore`) — it's fully reproducible from
these two scripts against the public source.
