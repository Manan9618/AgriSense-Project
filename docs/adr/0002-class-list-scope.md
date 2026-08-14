# ADR 0002: v1 class list scoped to Potato, Pepper, Tomato (10 classes)

## Status
Accepted — Week 1. Expected to be revisited after Week 13 pilot village selection.

## Context
The project plan calls for 8-10 disease/pest classes (Week 1) sourced from public datasets plus
supplementary field photos. The plan's own sample UI (Section 6) shows Cotton and Wheat as
illustrative crops, implying a possible Gujarat-region pilot, but does not commit to a region or
crop mix — that's a Week 13 decision (pilot logistics/coordinator training).

PlantVillage, the most complete public labeled crop-disease dataset, has no Cotton or Wheat
classes. It does have deep coverage (multiple diseases + healthy) for Potato, Pepper (bell), and
Tomato — all crops grown widely across Indian smallholder regions, not region-specific.

## Decision
Ship v1 with 10 classes across Potato, Pepper, and Tomato (see `docs/classes.md`), sourced
entirely from PlantVillage. Defer Cotton/Wheat (or any pilot-region-specific crop) to a
field-sourced supplementary dataset once the pilot region is locked in.

## Consequences
- Week 2-3 accuracy work is done against real, well-labeled data — no need to hand-label a
  bootstrap set before training v1.
- If the Week 13 pilot region turns out to be cotton/wheat-dominant, the class list changes and
  a new field-image collection effort is needed before those classes can be trained — flagged
  explicitly so it isn't a late surprise.
- The `AdvisoryMapper` (Week 5) and app class labels (Week 4) are built against this list; adding
  a class later means updating three places (model, advisory DB, app enum), not just the model.
