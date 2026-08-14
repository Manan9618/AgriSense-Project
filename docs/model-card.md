# Model Card — v1 Baseline Classifier (Week 2)

## Summary

MobileNetV2 (ImageNet-pretrained) transfer learning, fine-tuned on the 10-class PlantVillage
subset described in `docs/dataset-card.md`. Rationale in `docs/adr/0004-mobilenetv2-transfer-learning.md`.

| | |
|---|---|
| Architecture | MobileNetV2 (alpha=1.0, 224x224 input) + GlobalAveragePooling2D + Dropout(0.3) + Dense(10, softmax) |
| Training | 2-phase: 10 epochs frozen-base feature extraction (lr=1e-3), then 8 epochs fine-tuning layers 100-154 (lr=1e-5) |
| Training time | ~66 min total (26 min phase 1 + 40 min phase 2) on CPU, Apple M3 |
| Class imbalance handling | Per-class oversampling (capped 8x) + random augmentation (flip/rotation/zoom/contrast/brightness), applied to training split only — see `ml/scripts/data.py` |

## Accuracy

| Split | Accuracy | Notes |
|---|---|---|
| Validation | 97.60% | Used for checkpoint selection (`best.keras`) — slightly optimistic |
| **Test (held-out)** | **96.12%** | Never used for training or model selection |

Both comfortably clear the project's >85% target (Section 8, project plan). Test set is the
number that matters — it's the only one the model/training process never influenced.

## Per-class results (test set, n=1832)

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| potato_early_blight | 0.967 | 0.987 | 0.977 | 150 |
| potato_late_blight | 0.935 | 0.960 | 0.947 | 150 |
| potato_healthy | 0.957 | 0.957 | 0.957 | 23 |
| pepper_bell_bacterial_spot | 0.993 | 0.973 | 0.983 | 150 |
| pepper_bell_healthy | 0.974 | 0.995 | 0.984 | 222 |
| tomato_bacterial_spot | 0.981 | 0.981 | 0.981 | 319 |
| tomato_early_blight | 0.928 | **0.853** | 0.889 | 150 |
| tomato_late_blight | 0.942 | 0.913 | 0.927 | 286 |
| tomato_leaf_mold | 0.939 | 0.972 | 0.955 | 143 |
| tomato_healthy | 0.972 | 1.000 | 0.986 | 239 |
| **macro avg** | 0.959 | 0.959 | 0.959 | 1832 |
| **weighted avg** | 0.961 | 0.961 | 0.961 | 1832 |

`potato_healthy` (only 23 test images, 106 training images pre-oversampling — the smallest class
by far) still scored 0.957 F1, evidence the oversampling+augmentation approach is working rather
than the model simply ignoring the rare class.

## Weakest class: tomato_early_blight (0.853 recall)

Of 150 test images, 22 were misclassified — 10 as `tomato_late_blight`, the rest scattered.
Early and late blight look genuinely similar in early-stage lesions (both fungal leaf-spot
diseases; this is a known hard pair in the plant pathology literature, not an artifact of this
model). Not treated as a blocker for the Week 1 target, but worth tracking:
- Watch this pair specifically in the Week 22 field-vs-lab comparison — field photos may make the
  confusion worse (more lighting/angle variance) or better (farmers may photograph more
  advanced, more distinguishable lesions than the lab dataset's earlier-stage examples).
- A candidate first fix if it persists: more aggressive augmentation specifically for these two
  classes, or a higher input resolution — not worth doing preemptively without field evidence.

## Known limitations (carried over from `docs/dataset-card.md`)

- Trained and evaluated entirely on lab-conditions PlantVillage images — accuracy on real farmer
  phone photos (background clutter, variable lighting, partial leaf occlusion) is unmeasured
  until Week 13-16 field data exists. Treat 96% as an upper bound, not an on-device expectation.
- Preprocessing (`mobilenet_v2.preprocess_input`, scaling to [-1, 1]) is applied in the tf.data
  pipeline (`ml/scripts/data.py`), not baked into the model graph — Week 3's TFLite conversion
  needs to either embed this or replicate it in the Flutter app's capture pipeline. Flagged in
  ADR 0004.

## Reproducing

```bash
cd ml
source .venv/bin/activate
python scripts/train.py --run-name v1        # ~66 min on CPU (M3)
python scripts/evaluate.py --run-name v1
```

Trained weights (`ml/models/v1/`) are not committed to git — regenerate via the above, or see
`ml/models/v1/meta.json` / `ml/models/v1/eval/results.json` for full numeric results (also
gitignored, reproducible from the two commands above).
