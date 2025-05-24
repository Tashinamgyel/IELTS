// lib/services/firebase_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/essay.dart';

class FirebaseService {
  final String baseUrl = "https://ielts2-default-rtdb.asia-southeast1.firebasedatabase.app";

  Future<T> _retry<T>(Future<T> Function() action,
      {int retries = 3, Duration delay = const Duration(seconds: 2)}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        return await action();
      } catch (e) {
        if (attempt == retries - 1) rethrow;
        await Future.delayed(delay);
      }
    }
    throw Exception("Unreachable");
  }

  Future<void> saveEssay(Essay essay) async {
    final url = "$baseUrl/essays/${essay.id}.json";
    await _retry(() async {
      final response = await http.put(
        Uri.parse(url),
        body: jsonEncode(essay.toJson()),
      );
      if (response.statusCode != 200) {
        throw Exception('Error saving essay: ${response.body}');
      }
    });
  }

  Future<List<Essay>> getEssays() async {
    final url = "$baseUrl/essays.json";
    try {
      return await _retry(() async {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          List<Essay> essays = [];
          data.forEach((key, value) {
            essays.add(Essay.fromJson(Map<String, dynamic>.from(value)));
          });
          // Cache the result locally.
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('cached_essays', response.body);
          return essays;
        } else {
          throw Exception('Error fetching essays: ${response.body}');
        }
      });
    } catch (e) {
      // If network fails, try loading from cache.
      final prefs = await SharedPreferences.getInstance();
      String? cached = prefs.getString('cached_essays');
      if (cached != null) {
        final Map<String, dynamic> data = jsonDecode(cached);
        List<Essay> essays = [];
        data.forEach((key, value) {
          essays.add(Essay.fromJson(Map<String, dynamic>.from(value)));
        });
        return essays;
      }
      rethrow;
    }
  }

  Future<List<Essay>> getEssaysByTopic(String topic) async {
    final url = "$baseUrl/essays.json?orderBy=\"topic\"&equalTo=\"$topic\"";
    return await _retry(() async {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<Essay> essays = [];
        data.forEach((key, value) {
          essays.add(Essay.fromJson(Map<String, dynamic>.from(value)));
        });
        return essays;
      } else {
        throw Exception('Error fetching essays by topic: ${response.body}');
      }
    });
  }

  Future<void> updateEssayRating(String essayId, int newRating) async {
    final url = "$baseUrl/essays/$essayId.json";
    await _retry(() async {
      final response = await http.patch(
        Uri.parse(url),
        body: jsonEncode({'rating': newRating}),
      );
      if (response.statusCode != 200) {
        throw Exception('Error updating rating: ${response.body}');
      }
    });
  }

  Future<List<Essay>> getTopRatedEssays({int minRating = 5}) async {
    final url = "$baseUrl/essays.json?orderBy=\"rating\"&startAt=$minRating";
    return await _retry(() async {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        List<Essay> essays = [];
        data.forEach((key, value) {
          essays.add(Essay.fromJson(Map<String, dynamic>.from(value)));
        });
        essays.sort((a, b) => b.rating.compareTo(a.rating));
        return essays;
      } else {
        throw Exception('Error fetching top rated essays: ${response.body}');
      }
    });
  }

  Future<List<Essay>> getSavedEssays(String userId) async {
    final url = "$baseUrl/saved_essays/$userId.json";
    return await _retry(() async {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic>? data = jsonDecode(response.body);
        List<Essay> essays = [];
        if (data != null) {
          data.forEach((key, value) {
            essays.add(Essay.fromJson(Map<String, dynamic>.from(value)));
          });
        }
        return essays;
      } else {
        throw Exception('Error fetching saved essays: ${response.body}');
      }
    });
  }
}
