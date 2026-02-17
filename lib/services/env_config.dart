import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api';

  static Future<void> load({String? fileName}) async {
    await dotenv.load(fileName: fileName ?? '.env');
  }
}
