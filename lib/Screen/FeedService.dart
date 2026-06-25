import 'dart:convert';
import 'package:http/http.dart' as http;
import 'PostModel.dart';

class FeedService {
  static const String _baseUrl = 'http://207.154.255.210:8082';

  static Future<List<PostModel>> getGlobalFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/get/post/beta/v0?limit=$limit&offset=$offset');

    final response = await http.get(uri);

    // للديباغ - احذفها بعد ما تتأكد الكود شغال
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List postsJson = data['posts'] ?? [];
      return postsJson.map((e) => PostModel.fromJson(e)).toList();
    } else {
      throw Exception('فشل جلب البوستات: ${response.statusCode}');
    }
  }
}
