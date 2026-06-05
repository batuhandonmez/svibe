import 'package:flutter_test/flutter_test.dart';
import 'package:svibe/src/core/api/api_client.dart';

void main() {
  test('default API base URL is configured', () {
    expect(defaultApiBaseUrl(), isNotEmpty);
  });
}
