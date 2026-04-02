import 'package:http/http.dart' as http;
import 'dart:convert';

const String _aiServiceUrl = 'https://pfe-smartschool.onrender.com';

Future<Map<String, dynamic>?> callAIService({
  required int total,
  required int present,
  required int absent,
  required int late,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$_aiServiceUrl/analyze/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'total': total,
        'present': present,
        'absent': absent,
        'late': late,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (e) {
    print('AI service unavailable: $e');
  }
  return null;
}