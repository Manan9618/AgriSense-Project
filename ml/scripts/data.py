"""tf.data pipeline built from ml/data/manifest.csv (see prepare_dataset.py).

Handles class imbalance via oversampling: minority-class training images are
repeated (up to a cap) so the model sees more of them per epoch, then random
augmentation (flip/rotate/zoom/contrast/brightness) makes each repeat visually
distinct rather than a bit-for-bit duplicate. Val/test are left at their
natural distribution — oversampling only ever touches the training split, so
evaluation numbers reflect real-world class frequency.
"""

import csv
import json
from collections import defaultdict
from pathlib import Path

import tensorflow as tf

ML_DIR = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ML_DIR / "data" / "manifest.csv"
CLASS_NAMES_PATH = ML_DIR / "data" / "class_names.json"

IMAGE_SIZE = (224, 224)
OVERSAMPLE_CAP = 8  # a class is oversampled at most 8x, even if far below the majority count

_AUGMENTER = tf.keras.Sequential(
    [
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.15),
        tf.keras.layers.RandomZoom(0.15),
        tf.keras.layers.RandomContrast(0.15),
        tf.keras.layers.RandomBrightness(0.15, value_range=(0, 255)),
    ],
    name="augmentation",
)


def load_class_names() -> list[str]:
    with open(CLASS_NAMES_PATH) as f:
        return json.load(f)


def load_manifest_split(split: str) -> dict[str, list[str]]:
    """Returns {class_id: [absolute filepath, ...]} for the given split."""
    by_class = defaultdict(list)
    with open(MANIFEST_PATH, newline="") as f:
        for row in csv.DictReader(f):
            if row["split"] == split:
                by_class[row["class_id"]].append(str(ML_DIR / row["filepath"]))
    return dict(by_class)


def _oversampled_train_files(by_class: dict[str, list[str]]) -> tuple[list[str], list[str]]:
    max_count = max(len(paths) for paths in by_class.values())
    filepaths, class_ids = [], []
    for class_id, paths in by_class.items():
        target = min(max_count, len(paths) * OVERSAMPLE_CAP)
        repeated = [paths[i % len(paths)] for i in range(target)]
        filepaths.extend(repeated)
        class_ids.extend([class_id] * len(repeated))
    return filepaths, class_ids


def _decode_and_resize(filepath, label):
    image_bytes = tf.io.read_file(filepath)
    image = tf.io.decode_image(image_bytes, channels=3, expand_animations=False)
    image = tf.image.resize(image, IMAGE_SIZE)
    image.set_shape((*IMAGE_SIZE, 3))
    return image, label


def raw_examples(split: str, limit: int | None = None, seed: int = 42):
    """Yields (uint8 HWC image, class_id str) pairs, resized but otherwise
    unpreprocessed — no augmentation, no MobileNetV2 [-1, 1] scaling.

    Used for TFLite conversion's representative dataset (needs raw
    on-device-shaped input) and for comparing the quantized model's
    predictions against the float Keras model on identical inputs.
    """
    import random

    by_class = load_manifest_split(split)
    filepaths, class_ids = [], []
    for class_id, paths in by_class.items():
        filepaths.extend(paths)
        class_ids.extend([class_id] * len(paths))

    pairs = list(zip(filepaths, class_ids, strict=True))
    random.Random(seed).shuffle(pairs)
    if limit is not None:
        pairs = pairs[:limit]

    for filepath, class_id in pairs:
        image, _ = _decode_and_resize(filepath, 0)
        yield tf.cast(image, tf.uint8).numpy(), class_id


def make_dataset(split: str, batch_size: int = 32, shuffle_seed: int = 42) -> tf.data.Dataset:
    """Builds a preprocessed (image in [-1, 1], integer label) batched dataset.

    Training split is oversampled + augmented; val/test are neither, so they
    measure performance against the true class distribution.
    """
    class_names = load_class_names()
    class_to_index = {name: i for i, name in enumerate(class_names)}
    by_class = load_manifest_split(split)

    if split == "train":
        filepaths, class_ids = _oversampled_train_files(by_class)
    else:
        filepaths, class_ids = [], []
        for class_id, paths in by_class.items():
            filepaths.extend(paths)
            class_ids.extend([class_id] * len(paths))

    labels = [class_to_index[c] for c in class_ids]

    ds = tf.data.Dataset.from_tensor_slices((filepaths, labels))
    if split == "train":
        ds = ds.shuffle(
            buffer_size=len(filepaths), seed=shuffle_seed, reshuffle_each_iteration=True
        )
    ds = ds.map(_decode_and_resize, num_parallel_calls=tf.data.AUTOTUNE)

    if split == "train":
        ds = ds.map(
            lambda img, lbl: (_AUGMENTER(img, training=True), lbl),
            num_parallel_calls=tf.data.AUTOTUNE,
        )

    ds = ds.map(
        lambda img, lbl: (tf.keras.applications.mobilenet_v2.preprocess_input(img), lbl),
        num_parallel_calls=tf.data.AUTOTUNE,
    )
    ds = ds.batch(batch_size)
    return ds.prefetch(tf.data.AUTOTUNE)
