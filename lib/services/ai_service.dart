import 'dart:convert';
import 'package:http/http.dart' as http;
import 'remote_config_service.dart';

class AIService {
  static const String _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
  
  /// Supported models on OpenRouter
  static const String geminiFlash = 'google/gemini-2.0-flash-001';
  static const String deepseekChat = 'deepseek/deepseek-chat';
  
  /// Generic method to call OpenRouter (OpenAI compatible) API
  static Future<String> generateContent({
    required String prompt,
    String model = geminiFlash,
  }) async {
    final apiKey = RemoteConfigService.aiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('API Key is not configured. Please check Firebase Remote Config.');
    }

    try {
      final response = await http.post(
        Uri.parse(_openRouterUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://github.com/mohan-70/lagJa', // Recommended by OpenRouter
          'X-Title': 'Lagja',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('OpenRouter Error (${response.statusCode}): ${error['error']?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
