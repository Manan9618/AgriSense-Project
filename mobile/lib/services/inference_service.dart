import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/diagnosis_prediction.dart';

/// Wraps the bundled quantized crop-disease classifier
/// (assets/models/agrisense_v1_int8.tflite — see docs/model-card.md).
///
/// The model's input preprocessing (uint8 -> [-1, 1] scaling) is baked into
/// the TFLite graph itself (docs/adr/0005-tflite-int8-quantization.md), so
/// this class only resizes the photo to 224x224 and hands raw RGB bytes
/// straight to the interpreter — no manual normalization to keep in sync
/// with the training pipeline.
class InferenceService {
  InferenceService._(this._interpreter, this.classNames);

  static const modelAsset = 'assets/models/agrisense_v1_int8.tflite';
  static const classNamesAsset = 'assets/models/class_names.json';
  static const inputSize = 224;

  final Interpreter _interpreter;
  final List<String> classNames;

  static Future<InferenceService> load() async {
    final interpreter = await Interpreter.fromAsset(modelAsset);
    final classNamesJson = await rootBundle.loadString(classNamesAsset);
    final classNames = (jsonDecode(classNamesJson) as List).cast<String>();
    return InferenceService._(interpreter, classNames);
  }

  /// Classifies an already-decoded image, resizing it to the model's
  /// expected 224x224 input. Runs synchronously on the calling isolate —
  /// fine for a single user-initiated scan; if UI jank shows up on
  /// low-end devices, move this to a background isolate (candidate for
  /// Week 20's performance pass, not needed for the Week 4 baseline).
  DiagnosisPrediction classify(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    final imageMatrix = List.generate(
      inputSize,
      (y) => List.generate(inputSize, (x) {
        final pixel = resized.getPixel(x, y);
        return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
      }),
    );

    final input = [imageMatrix];
    final output = [List<double>.filled(classNames.length, 0.0)];
    _interpreter.run(input, output);

    final probs = output.first;
    var bestIndex = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[bestIndex]) bestIndex = i;
    }
    return DiagnosisPrediction(
      classId: classNames[bestIndex],
      confidence: probs[bestIndex],
    );
  }

  void close() => _interpreter.close();
}
