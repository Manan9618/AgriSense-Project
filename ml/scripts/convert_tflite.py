#!/usr/bin/env python3
"""Convert the trained Keras model to a quantized, on-device-ready TFLite model.

Wraps the trained classifier with a preprocessing input layer first, so the
exported .tflite takes raw uint8 [0, 255] 224x224x3 images — exactly what a
Flutter camera plugin hands over — rather than requiring the app to replicate
MobileNetV2's [-1, 1] preprocessing in Dart (the gap flagged in
docs/adr/0004-mobilenetv2-transfer-learning.md).

Full integer (int8) post-training quantization, calibrated against a sample
of real training images (`converter.representative_dataset`) — the "post-
training quantization with careful calibration" approach the project plan's
hard-challenges table (Section 11.2) calls for. Output stays float32 so
confidence scores remain directly interpretable as probabilities; only the
input tensor and internal compute are int8.

Usage:
    python scripts/convert_tflite.py --run-name v1
"""

import argparse
from pathlib import Path

import tensorflow as tf
from data import IMAGE_SIZE, raw_examples

ML_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = ML_DIR / "models"

REPRESENTATIVE_SAMPLE_SIZE = 200


def build_wrapper(trained_model: tf.keras.Model) -> tf.keras.Model:
    # Equivalent to mobilenet_v2.preprocess_input's 'tf' mode (x/127.5 - 1),
    # expressed as Keras layers since Keras 3 rejects bare tf.* calls on a
    # KerasTensor (only keras.layers/keras.ops are allowed in the graph).
    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3), dtype=tf.uint8, name="image_uint8")
    x = tf.keras.layers.Lambda(lambda t: tf.cast(t, tf.float32), output_shape=(*IMAGE_SIZE, 3))(
        inputs
    )
    x = tf.keras.layers.Rescaling(scale=1.0 / 127.5, offset=-1.0)(x)
    outputs = trained_model(x, training=False)
    return tf.keras.Model(inputs, outputs, name="agrisense_crop_classifier")


def representative_dataset_gen():
    for image, _class_id in raw_examples("train", limit=REPRESENTATIVE_SAMPLE_SIZE):
        yield [image[None, ...]]  # add batch dim, stays uint8


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-name", default="v1")
    parser.add_argument("--checkpoint", default="best.keras")
    parser.add_argument("--out-name", default="model_int8.tflite")
    args = parser.parse_args()

    run_dir = MODELS_DIR / args.run_name
    trained_model = tf.keras.models.load_model(run_dir / args.checkpoint)
    wrapper = build_wrapper(trained_model)

    converter = tf.lite.TFLiteConverter.from_keras_model(wrapper)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset_gen
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.uint8
    converter.inference_output_type = tf.float32

    print(
        f"Converting {args.checkpoint} -> {args.out_name} (int8, calibrated on "
        f"{REPRESENTATIVE_SAMPLE_SIZE} training images)..."
    )
    tflite_model = converter.convert()

    out_path = run_dir / args.out_name
    out_path.write_bytes(tflite_model)

    size_mb = out_path.stat().st_size / (1024 * 1024)
    print(f"Saved {out_path} ({size_mb:.2f} MB)")


if __name__ == "__main__":
    main()
