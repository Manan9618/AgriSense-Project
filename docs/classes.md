# Target Disease/Pest Class List

10 classes across 3 crops (Potato, Pepper, Tomato) — all widely grown by Indian smallholder
farmers and well-represented in the PlantVillage public dataset, our Week 1 source before
supplementary field photos are collected during the Week 13-16 pilot.

Tomato carries the most classes deliberately: it's grown across nearly every pilot-relevant
region, has the richest disease variety in the source dataset, and gives us a natural class
imbalance to handle in Week 2 (augmentation) rather than a synthetic one.

| # | Class ID | Crop | Condition | Type |
|---|----------|------|-----------|------|
| 1 | `potato_early_blight` | Potato | Early blight (*Alternaria solani*) | Disease |
| 2 | `potato_late_blight` | Potato | Late blight (*Phytophthora infestans*) | Disease |
| 3 | `potato_healthy` | Potato | Healthy | Healthy |
| 4 | `pepper_bell_bacterial_spot` | Pepper (bell) | Bacterial spot (*Xanthomonas campestris*) | Disease |
| 5 | `pepper_bell_healthy` | Pepper (bell) | Healthy | Healthy |
| 6 | `tomato_bacterial_spot` | Tomato | Bacterial spot (*Xanthomonas spp.*) | Disease |
| 7 | `tomato_early_blight` | Tomato | Early blight (*Alternaria solani*) | Disease |
| 8 | `tomato_late_blight` | Tomato | Late blight (*Phytophthora infestans*) | Disease |
| 9 | `tomato_leaf_mold` | Tomato | Leaf mold (*Passalora fulva*) | Disease |
| 10 | `tomato_healthy` | Tomato | Healthy | Healthy |

## Source dataset mapping

Maps 1:1 to PlantVillage's `raw/color` folder names:

| Class ID | PlantVillage folder |
|---|---|
| `potato_early_blight` | `Potato___Early_blight` |
| `potato_late_blight` | `Potato___Late_blight` |
| `potato_healthy` | `Potato___healthy` |
| `pepper_bell_bacterial_spot` | `Pepper,_bell___Bacterial_spot` |
| `pepper_bell_healthy` | `Pepper,_bell___healthy` |
| `tomato_bacterial_spot` | `Tomato___Bacterial_spot` |
| `tomato_early_blight` | `Tomato___Early_blight` |
| `tomato_late_blight` | `Tomato___Late_blight` |
| `tomato_leaf_mold` | `Tomato___Leaf_Mold` |
| `tomato_healthy` | `Tomato___healthy` |

## Why these 10 and not others

- **Excludes** rare/ambiguous PlantVillage classes (e.g. mite damage, viral classes with subtle
  visual signatures) for v1 — those are candidates for the Week 12 feedback-driven retraining
  pipeline once we have field data to validate against, not lab data alone.
- **Excludes** crops outside the three above (Apple, Grape, Corn, etc.) to keep the v1 scope
  tight enough to hit the >85% accuracy target in Week 2-3 rather than spreading thin across
  many crops with few images each.
- Cotton and Wheat appear in the plan's sample UI mockup (Section 6 of the project PDF) as
  illustrative examples, not as a scope commitment — PlantVillage has no Cotton/Wheat classes,
  so those would need a separate field-sourced dataset. Revisit if the pilot region (Week 13)
  turns out to be cotton/wheat-dominant; see `docs/adr/0002-class-list-scope.md`.

## Revising this list

This list is expected to evolve:
- Week 12 (`FeedbackCollector`) — retraining pipeline design should support adding classes.
- Week 13 (pilot village recruitment) — actual regional crop mix may require swapping classes.
- Week 16 (mid-pilot iteration) — field images may reveal need for an "unknown/low-confidence"
  catch-all class not in this list.
