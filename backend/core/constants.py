"""Single source of truth for the target disease/pest class list.

Mirrors docs/classes.md at the repo root — update both together. Referenced by
Diagnosis.predicted_class so the backend can only ever store a class the model
(and the app's AdvisoryMapper) actually knows about.
"""

DISEASE_CLASSES = [
    ("potato_early_blight", "Potato — Early blight"),
    ("potato_late_blight", "Potato — Late blight"),
    ("potato_healthy", "Potato — Healthy"),
    ("pepper_bell_bacterial_spot", "Pepper (bell) — Bacterial spot"),
    ("pepper_bell_healthy", "Pepper (bell) — Healthy"),
    ("tomato_bacterial_spot", "Tomato — Bacterial spot"),
    ("tomato_early_blight", "Tomato — Early blight"),
    ("tomato_late_blight", "Tomato — Late blight"),
    ("tomato_leaf_mold", "Tomato — Leaf mold"),
    ("tomato_healthy", "Tomato — Healthy"),
]

DISEASE_CLASS_IDS = [class_id for class_id, _ in DISEASE_CLASSES]
