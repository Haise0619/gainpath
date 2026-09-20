enum BackendMode { mock, firebase }

class BackendConfig {
  const BackendConfig(this.mode, {this.isProduction = false});

  final BackendMode mode;
  final bool isProduction;

  void validate() {
    if ((isProduction || const bool.fromEnvironment('dart.vm.product')) &&
        isMock) {
      throw StateError('Mock backends are forbidden in production.');
    }
  }

  bool get isMock => mode == BackendMode.mock;
  bool get isFirebase => mode == BackendMode.firebase;

  factory BackendConfig.fromEnvironment() {
    const raw = String.fromEnvironment('BACKEND', defaultValue: 'mock');
    const environment =
        String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return BackendConfig.parse(raw,
        isProduction: environment == 'production' ||
            const bool.fromEnvironment('dart.vm.product'));
  }

  factory BackendConfig.parse(String? raw, {bool isProduction = false}) {
    if (isProduction &&
        (raw == null ||
            raw.trim().isEmpty ||
            raw.trim().toLowerCase() == 'mock')) {
      throw StateError('Mock backends are forbidden in production.');
    }
    switch (raw?.trim().toLowerCase()) {
      case null:
      case '':
      case 'mock':
        return BackendConfig(BackendMode.mock, isProduction: isProduction);
      case 'firebase':
        return BackendConfig(BackendMode.firebase, isProduction: isProduction);
      default:
        throw ArgumentError.value(raw, 'BACKEND', 'Expected mock or firebase');
    }
  }
}
