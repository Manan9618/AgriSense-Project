#!/usr/bin/env python3
"""Validate accuracy retention: quantized TFLite model vs. the float Keras model.

Runs the .tflite model over the held-out test split and reports accuracy plus
the drop versus the float model's test accuracy (from
ml/models/<run>/eval/results.json, written by evaluate.py) — the "<3%
tolerance" check called for in the project plan's hard-challenges table
(Section 11.2).

Usage:
    python scripts/evaluate_tflite.py --run-name v1
"""

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from data import load_class_names, raw_examples
from sklearn.metrics import classification_report

ML_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = ML_DIR / "models"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-name", default="v1")
    parser.add_argument("--model-file", default="model_int8.tflite")
    args = parser.parse_args()

    run_dir = MODELS_DIR / args.run_name
    class_names = load_class_names()
    class_to_index = {name: i for i, name in enumerate(class_names)}

    interpreter = tf.lite.Interpreter(model_path=str(run_dir / args.model_file))
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]

    y_true, y_pred = [], []
    for image, class_id in raw_examples("test"):
        interpreter.set_tensor(input_detail["index"], image[None, ...])
        interpreter.invoke()
        probs = interpreter.get_tensor(output_detail["index"])[0]
        y_true.append(class_to_index[class_id])
        y_pred.append(int(np.argmax(probs)))

    report = classification_report(
        y_true, y_pred, target_names=class_names, output_dict=True, zero_division=0
    )
    tflite_accuracy = report["accuracy"]
    print(f"TFLite (int8) test accuracy: {tflite_accuracy:.4f} (n={len(y_true)})")

    float_results_path = run_dir / "eval" / "results.json"
    comparison = {"tflite_test_accuracy": tflite_accuracy, "n_examples": len(y_true)}
    if float_results_path.exists():
        float_accuracy = json.loads(float_results_path.read_text())["test"]["report"]["accuracy"]
        drop = float_accuracy - tflite_accuracy
        comparison["float_test_accuracy"] = float_accuracy
        comparison["accuracy_drop"] = round(drop, 4)
        comparison["within_3pct_tolerance"] = drop < 0.03
        print(f"Float (Keras) test accuracy:  {float_accuracy:.4f}")
        print(
            f"Accuracy drop from quantization: {drop:+.4f} "
            f"({'within' if drop < 0.03 else 'EXCEEDS'} 3% tolerance)"
        )
    else:
        print(f"(no {float_results_path} found — run evaluate.py first to get the comparison)")

    comparison["report"] = report
    out_path = run_dir / "eval" / "tflite_results.json"
    out_path.write_text(json.dumps(comparison, indent=2))
    print(f"\nWrote {out_path}")


if __name__ == "__main__":
    main()
