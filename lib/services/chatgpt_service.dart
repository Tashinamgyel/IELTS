// lib/services/chatgpt_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/essay.dart';

// Prompt constants.
const String systemMessage =
    'You are an expert IELTS essay writer. Create a well-structured IELTS essay with introduction, body paragraphs, and conclusion.';
const String userMessageTemplate =
    'Write an IELTS essay on the following topic:';

class ChatGPTService {
  final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final String apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> generateEssay(String topic) async {
    if (apiKey.isEmpty) {
      throw Exception('API key not found');
    }

    int retries = 3;
    for (int attempt = 0; attempt < retries; attempt++) {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': systemMessage,
            },
            {
              'role': 'user',
              'content': '$userMessageTemplate $topic',
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        if (kDebugMode) {
          print("Error generating essay (attempt ${attempt + 1}): ${response.body}");
        }
        if (attempt < retries - 1) {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          throw Exception('Failed to generate essay. Please try again later.');
        }
      }
    }
    throw Exception('Unreachable');
  }

  Future<Essay> createEssay(String topic) async {
    final content = await generateEssay(topic);
    return Essay(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      topic: topic,
      content: content,
      createdAt: DateTime.now(),
    );
  }
}
