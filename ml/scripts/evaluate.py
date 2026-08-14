#!/usr/bin/env python3
"""Evaluate a trained model: per-class precision/recall/F1 + confusion matrix.

Runs against both val (used for early-stopping/checkpointing during training,
so slightly optimistic) and test (never seen during training or model
selection) splits, since the project's success metric (>85% accuracy) should
be reported against held-out data the model never influenced.

Usage:
    python scripts/evaluate.py --run-name v1
"""

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from data import load_class_names, make_dataset
from sklearn.metrics import classification_report, confusion_matrix

ML_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = ML_DIR / "models"


def evaluate_split(model, split: str, class_names: list[str]) -> dict:
    ds = make_dataset(split, batch_size=32)
    y_true, y_pred = [], []
    for images, labels in ds:
        probs = model.predict(images, verbose=0)
        y_true.extend(labels.numpy().tolist())
        y_pred.extend(np.argmax(probs, axis=1).tolist())

    report = classification_report(
        y_true, y_pred, target_names=class_names, output_dict=True, zero_division=0
    )
    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(class_names))))
    return {"report": report, "confusion_matrix": cm.tolist(), "n_examples": len(y_true)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-name", default="v1")
    parser.add_argument(
        "--checkpoint",
        default="best.keras",
        help="best.keras (highest val_accuracy) or final.keras",
    )
    args = parser.parse_args()

    run_dir = MODELS_DIR / args.run_name
    model = tf.keras.models.load_model(run_dir / args.checkpoint)
    class_names = load_class_names()

    results = {}
    for split in ["val", "test"]:
        print(f"Evaluating on {split}...")
        results[split] = evaluate_split(model, split, class_names)
        acc = results[split]["report"]["accuracy"]
        print(f"  {split} accuracy: {acc:.4f} (n={results[split]['n_examples']})")

    eval_dir = run_dir / "eval"
    eval_dir.mkdir(exist_ok=True)
    (eval_dir / "results.json").write_text(json.dumps(results, indent=2))
    print(f"\nWrote full results to {eval_dir / 'results.json'}")


if __name__ == "__main__":
    main()
