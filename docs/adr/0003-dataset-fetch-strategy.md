# ADR 0003: Sparse partial clone for dataset fetch, nothing committed to git

## Status
Accepted — Week 1

## Context
PlantVillage-Dataset is a public GitHub repo but ~2GB across all crops/classes/variants
(color/grayscale/segmented). We only need 10 classes' `raw/color` images (~220MB, see
`docs/dataset-card.md`). A full clone or a Kaggle-API-key-gated download were the two obvious
alternatives; both pull far more than we need or add an auth dependency for a Week 1 setup step.

## Decision
`ml/scripts/download_dataset.py` does a `git clone --filter=blob:none --sparse` (partial +
sparse checkout) scoped to just the needed class folders, then copies images into
`ml/data/raw/<our_class_id>/` using the mapping in `ml/scripts/class_map.py`, and deletes the git
cache afterward. Nothing under `ml/data/` is committed — the two scripts
(`download_dataset.py`, `prepare_dataset.py`) are the reproducibility mechanism, not a data
snapshot in git.

## Consequences
- Fetch is a no-auth, ~220MB, few-minute operation — reproducible in CI or a fresh clone without
  secrets management.
- `class_map.py` and `docs/classes.md` must be kept in sync by hand (only 10 entries, low risk).
- If PlantVillage's upstream repo structure changes or the repo disappears, the fetch script
  breaks — acceptable risk for a public, widely-mirrored academic dataset, revisit if it happens.
- Supplementary field photos collected during the Week 13-16 pilot will need their own ingestion
  path into the same `ml/data/raw/<class_id>/` layout — not designed yet, deferred to Week 12
  (`FeedbackCollector` / retraining pipeline design).
