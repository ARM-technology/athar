import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class LocalUserStorage {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/user.json');
  }

  /// 🟢 الميثود الأولى: إنشاء وحفظ المستخدم محليًا
  static Future<void> saveUser({
    required String userId,
    required String name,
  }) async {
    final file = await _getFile();

    final data = {
      "userId": userId,
      "name": name,
      "createdAt": DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(data));
  }


  /// 🔵 الميثود الثانية: قراءة المستخدم من الجهاز
  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) return null;

      final content = await file.readAsString();
      return jsonDecode(content);
    } catch (e) {
      return null;
    }
  }


  /// 🟡 الميثود الثالثة: التحقق من وجود المستخدم محليًا
  static Future<bool> isUserExists() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        return false;
      }

      final content = await file.readAsString();

      if (content.isEmpty) {
        return false;
      }

      final data = jsonDecode(content);

      // تأكد أن البيانات الأساسية موجودة
      if (data["userId"] == null || data["userId"].toString().isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }



}




