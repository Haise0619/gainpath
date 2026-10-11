class PoseTensorSpec {
  const PoseTensorSpec(this.name, this.shape, this.type);
  final String name, type;
  final List<int> shape;
}

class BlazePoseModelContract {
  const BlazePoseModelContract(
      this.assetPath, this.sha256, this.input, this.outputs);
  final String assetPath, sha256;
  final PoseTensorSpec input;
  final List<PoseTensorSpec> outputs;
  static const detector = BlazePoseModelContract(
      'assets/models/pose_detection.tflite',
      '9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c',
      PoseTensorSpec('input_1', [1, 224, 224, 3], 'float32'), [
    PoseTensorSpec('Identity', [1, 2254, 12], 'float32'),
    PoseTensorSpec('Identity_1', [1, 2254, 1], 'float32'),
  ]);
  static const landmark = BlazePoseModelContract(
      'assets/models/pose_landmark_full.tflite',
      'e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f',
      PoseTensorSpec('input_1', [1, 256, 256, 3], 'float32'), [
    PoseTensorSpec('Identity', [1, 195], 'float32'),
    PoseTensorSpec('Identity_1', [1, 1], 'float32'),
    PoseTensorSpec('Identity_2', [1, 256, 256, 1], 'float32'),
    PoseTensorSpec('Identity_3', [1, 64, 64, 39], 'float32'),
    PoseTensorSpec('Identity_4', [1, 117], 'float32'),
  ]);
  static const version = 'mediapipe-full-e9a5c5cb-det-9ba9dd3d';

  void validate(
      PoseTensorSpec actualInput, List<PoseTensorSpec> actualOutputs) {
    bool matches(PoseTensorSpec a, PoseTensorSpec b) =>
        a.name == b.name &&
        a.type == b.type &&
        a.shape.length == b.shape.length &&
        List.generate(a.shape.length, (i) => a.shape[i] == b.shape[i])
            .every((v) => v);
    if (!matches(input, actualInput) ||
        actualOutputs.length != outputs.length ||
        !List.generate(
                outputs.length, (i) => matches(outputs[i], actualOutputs[i]))
            .every((v) => v)) {
      throw StateError(
          'BlazePose tensor contract does not match verified asset: $assetPath');
    }
  }
}
