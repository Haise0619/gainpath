import 'package:test/test.dart';
import 'package:gainpath_data/gainpath_data.dart';

void main() {
  test('backend configuration defaults to mock mode for local development', () {
    expect(BackendConfig.parse(null).mode, BackendMode.mock);
    expect(BackendConfig.parse('mock').mode, BackendMode.mock);
  });

  test('backend configuration accepts firebase mode explicitly', () {
    expect(BackendConfig.parse('firebase').mode, BackendMode.firebase);
  });

  test('unknown backend mode fails closed instead of silently using mock data',
      () {
    expect(() => BackendConfig.parse('production'), throwsArgumentError);
  });
}
