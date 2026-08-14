# ADR 0005: Full int8 quantization with preprocessing baked into the graph

## Status
Accepted — Week 3

## Context
ADR 0004 flagged a gap: the trained model expects input already scaled to [-1, 1]
(`mobilenet_v2.preprocess_input`), applied in the Python training pipeline
(`ml/scripts/data.py`), not in the model graph. Left as-is, the Flutter app would need to
replicate that exact scaling in Dart on every camera frame before inference — an easy place for
a silent, hard-to-debug accuracy regression if the two implementations ever drift.

Separately, Week 3 needs the model quantized for size (<15MB target) and speed. TFLite offers a
few post-training quantization levels: dynamic-range (weights only), float16, and full integer
(int8 weights + activations, calibrated against sample data).

## Decision
Two changes bundled together, both in `ml/scripts/convert_tflite.py`:
1. Wrap the trained model with an input layer that takes raw `uint8` [0, 255] images and applies
   the exact same rescale (`x/127.5 - 1`) as a Keras `Rescaling` layer, *before* conversion — so
   preprocessing ships inside the `.tflite` file itself.
2. Full integer (int8) quantization via `TFLITE_BUILTINS_INT8`, calibrated on 200 real training
   images (`representative_dataset`), with `inference_input_type=uint8` /
   `inference_output_type=float32` — input matches raw camera bytes exactly, output stays
   directly interpretable as a probability vector.

## Consequences
- The Flutter app's job becomes "decode camera frame, resize to 224x224, hand raw bytes to the
  interpreter" — no preprocessing logic to keep in sync with the training pipeline. Removes an
  entire class of future bugs at the cost of a slightly more involved conversion script.
- Result: 2.63MB (target <15MB), 95.20% test accuracy vs. 96.12% float (0.93pp drop, within the
  plan's <3% tolerance for quantization-induced accuracy loss). Numbers in `docs/model-card.md`.
- Full int8 (vs. dynamic-range or float16) was chosen over the lighter alternatives because the
  size/accuracy tradeoff already lands comfortably inside both targets — no need for a less
  aggressive quantization mode that would only buy back accuracy we don't need at the cost of
  size we don't have to spend.
- Used `tf.lite.Interpreter`/`TFLiteConverter`, which TF 2.21 flags as deprecated in favor of the
  separate `ai_edge_litert` package. Kept the built-in API for now — it still works, and the
  project plan's stack explicitly names "TensorFlow Lite," not LiteRT. Revisit if `tf.lite` is
  actually removed in a future TF version before this project ships.
