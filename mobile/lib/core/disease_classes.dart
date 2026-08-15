/// Crop + condition labels for each class_id the model predicts.
///
/// Mirrors docs/classes.md at the repo root (same source of truth as
/// backend/core/constants.py and ml/scripts/class_map.py) — update all
/// three together. Kept as an explicit table rather than parsed from the
/// class_id string because a couple of crop names are themselves
/// multi-word ("Pepper (bell)"), which naive underscore-splitting gets
/// wrong.
class DiseaseClassInfo {
  const DiseaseClassInfo({
    required this.crop,
    required this.condition,
    required this.isHealthy,
  });

  final String crop;
  final String condition;
  final bool isHealthy;
}

const Map<String, DiseaseClassInfo> diseaseClasses = {
  'potato_early_blight': DiseaseClassInfo(
    crop: 'Potato',
    condition: 'Early blight',
    isHealthy: false,
  ),
  'potato_late_blight': DiseaseClassInfo(
    crop: 'Potato',
    condition: 'Late blight',
    isHealthy: false,
  ),
  'potato_healthy': DiseaseClassInfo(
    crop: 'Potato',
    condition: 'Healthy',
    isHealthy: true,
  ),
  'pepper_bell_bacterial_spot': DiseaseClassInfo(
    crop: 'Pepper (bell)',
    condition: 'Bacterial spot',
    isHealthy: false,
  ),
  'pepper_bell_healthy': DiseaseClassInfo(
    crop: 'Pepper (bell)',
    condition: 'Healthy',
    isHealthy: true,
  ),
  'tomato_bacterial_spot': DiseaseClassInfo(
    crop: 'Tomato',
    condition: 'Bacterial spot',
    isHealthy: false,
  ),
  'tomato_early_blight': DiseaseClassInfo(
    crop: 'Tomato',
    condition: 'Early blight',
    isHealthy: false,
  ),
  'tomato_late_blight': DiseaseClassInfo(
    crop: 'Tomato',
    condition: 'Late blight',
    isHealthy: false,
  ),
  'tomato_leaf_mold': DiseaseClassInfo(
    crop: 'Tomato',
    condition: 'Leaf mold',
    isHealthy: false,
  ),
  'tomato_healthy': DiseaseClassInfo(
    crop: 'Tomato',
    condition: 'Healthy',
    isHealthy: true,
  ),
};
