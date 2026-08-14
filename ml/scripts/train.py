#!/usr/bin/env python3
"""Train the v1 baseline classifier: MobileNetV2 transfer learning.

Two phases, standard for transfer learning:
  1. Feature extraction — MobileNetV2 base frozen, only the new classifier
     head trains. Fast, stabilizes the head before touching pretrained
     weights.
  2. Fine-tuning — unfreeze the base's last N layers, continue training at a
     much lower learning rate so pretrained features adapt to crop-leaf
     images without being destroyed by large early-training gradients.

Saves the trained model plus per-epoch history to ml/models/<run_name>/ (not
committed to git — see docs/model-card.md for the numbers that matter).

Usage:
    python scripts/train.py
    python scripts/train.py --run-name v1 --phase1-epochs 10 --phase2-epochs 8
"""

import argparse
import json
import time
from pathlib import Path

import tensorflow as tf
from data import IMAGE_SIZE, load_class_names, make_dataset

ML_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = ML_DIR / "models"

FINE_TUNE_AT_LAYER = 100  # unfreeze MobileNetV2 layers from this index onward (of 154 total)


def build_model(n_classes: int) -> tuple[tf.keras.Model, tf.keras.Model]:
    """Returns (full_model, base_model) — base kept separate so train() can
    toggle base.trainable between phases without rebuilding the graph."""
    base = tf.keras.applications.MobileNetV2(
        input_shape=(*IMAGE_SIZE, 3), include_top=False, weights="imagenet"
    )
    base.trainable = False

    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3))
    x = base(inputs, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    outputs = tf.keras.layers.Dense(n_classes, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)
    return model, base


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-name", default="v1")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--phase1-epochs", type=int, default=10)
    parser.add_argument("--phase2-epochs", type=int, default=8)
    parser.add_argument("--phase1-lr", type=float, default=1e-3)
    parser.add_argument("--phase2-lr", type=float, default=1e-5)
    args = parser.parse_args()

    class_names = load_class_names()
    train_ds = make_dataset("train", batch_size=args.batch_size)
    val_ds = make_dataset("val", batch_size=args.batch_size)

    run_dir = MODELS_DIR / args.run_name
    run_dir.mkdir(parents=True, exist_ok=True)

    model, base = build_model(len(class_names))

    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            str(run_dir / "best.keras"), monitor="val_accuracy", save_best_only=True
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=5, restore_best_weights=True
        ),
    ]

    print(f"\n=== Phase 1: feature extraction ({args.phase1_epochs} epochs, base frozen) ===")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(args.phase1_lr),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    t0 = time.time()
    history1 = model.fit(
        train_ds, validation_data=val_ds, epochs=args.phase1_epochs, callbacks=callbacks
    )
    phase1_seconds = time.time() - t0

    print(
        f"\n=== Phase 2: fine-tuning ({args.phase2_epochs} epochs, base unfrozen from layer "
        f"{FINE_TUNE_AT_LAYER}) ==="
    )
    base.trainable = True
    for layer in base.layers[:FINE_TUNE_AT_LAYER]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(args.phase2_lr),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    t0 = time.time()
    history2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.phase1_epochs + args.phase2_epochs,
        initial_epoch=len(history1.history["loss"]),
        callbacks=callbacks,
    )
    phase2_seconds = time.time() - t0

    model.save(run_dir / "final.keras")

    combined_history = {k: history1.history[k] + history2.history[k] for k in history1.history}
    (run_dir / "history.json").write_text(json.dumps(combined_history, indent=2))
    (run_dir / "class_names.json").write_text(json.dumps(class_names, indent=2))
    (run_dir / "meta.json").write_text(
        json.dumps(
            {
                "run_name": args.run_name,
                "phase1_epochs_ran": len(history1.history["loss"]),
                "phase2_epochs_ran": len(history2.history["loss"]),
                "phase1_seconds": round(phase1_seconds, 1),
                "phase2_seconds": round(phase2_seconds, 1),
                "fine_tune_at_layer": FINE_TUNE_AT_LAYER,
                "image_size": IMAGE_SIZE,
                "best_val_accuracy": max(combined_history["val_accuracy"]),
            },
            indent=2,
        )
    )

    print(f"\nSaved best/final models + history to {run_dir}/")
    print(f"Best val_accuracy: {max(combined_history['val_accuracy']):.4f}")


if __name__ == "__main__":
    main()
