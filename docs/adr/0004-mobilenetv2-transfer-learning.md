# ADR 0004: MobileNetV2 transfer learning for the baseline classifier

## Status
Accepted — Week 2

## Context
Week 2 calls for a "baseline CNN classifier." Two real options: a small CNN trained from scratch
on our ~8.5k training images, or transfer learning on a pretrained mobile-friendly backbone. This
was raised explicitly with the project owner rather than defaulted, since it affects both how
likely we are to hit the >85% accuracy target (Section 8 of the project plan) and how easily the
Week 3 TFLite conversion hits the <15MB size target — a from-scratch architecture picked purely
for Week 2 convenience could make Week 3 much harder.

## Decision
Transfer learning: MobileNetV2 (ImageNet weights, alpha=1.0, 224x224 input), classifier head
replaced, trained in two phases — frozen-base feature extraction, then fine-tuning the last ~54
of 154 layers at a low learning rate. MobileNetV2 was designed for exactly this deployment
target (mobile, quantizes cleanly), so choosing it now means Week 3 is converting/quantizing an
architecture built for that job, not retrofitting one that wasn't.

## Consequences
- Reached 89.8%+ val accuracy after just 1+1 epochs in a smoke test — pretrained ImageNet
  features transfer well to leaf imagery, well above the >85% target with room to spare for the
  accuracy drop quantization (Week 3) and field-vs-lab gap (Week 22) will both introduce.
- Base model params (~2.3M) are small enough that even before quantization the model is a
  fraction of typical "from scratch" CNNs sized for this problem, which sets up the <15MB
  post-quantization target (Section 8) as a near-certainty rather than a stretch goal.
- Cost: this is a "baseline" only in the sense of "first working model" — it's not a
  from-first-principles CNN, so it teaches less about CNN architecture design. Acceptable
  trade-off given the project's learning objectives (Section 1.2) emphasize quantization,
  offline deployment, and field validation over architecture research.
- MobileNetV2's ImageNet preprocessing (`mobilenet_v2.preprocess_input`, scaling to [-1, 1]) is
  applied in `ml/scripts/data.py`'s tf.data pipeline, not baked into the exported model graph.
  Week 3 needs to either bake this into the TFLite graph or replicate it in the Flutter app's
  pre-inference image processing — flagged here so it isn't a surprise mid-conversion.
