import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../DataBaseSQLite/LocalSave.dart';
import '../../core/Statemanagement.dart';

class ScreenPost extends ConsumerStatefulWidget {
  const ScreenPost({super.key});

  @override
  ConsumerState<ScreenPost> createState() => _ScreenPostState();
}

class _ScreenPostState extends ConsumerState<ScreenPost> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addPost() async {
    // تحقق من الحقول قبل الإرسال
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء العنوان والمحتوى')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // جيب بيانات المستخدم من الجهاز
      final user = await LocalUserStorage.getUser();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
          );
        }
        return;
      }

      final String userID = user['userId'] ?? '';
      final String username = user['name'] ?? '';

      // أرسل البوست للسيرفر
      final response = await http.post(
        Uri.parse('http://207.154.255.210:8082/posts/add'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userID": userID,
          "username": username,
          "title": _titleController.text.trim(),
          "content": _contentController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        // نجح الإرسال - امسح الحقول وارجع للشاشة السابقة
        _titleController.clear();
        _contentController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نشر المنشور بنجاح! 🎉')),
          );
          // رجوع للفيد عبر الـ IndexedStack
          ref.read(counterProvider.notifier).state = 0;
        }
      } else {
        throw Exception('فشل الإرسال: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدام MediaQuery مباشرة - أضمن وأسرع من الـ providers
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHight = MediaQuery.of(context).size.height;

    return Container(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Container(
            height: screenHight * 0.7,
            width: screenWidth * 0.9,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(16),
              children: [

                // صندوق العنوان
                TextField(
                  controller: _titleController,
                  maxLength: 50,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'العنوان',
                    hintText: 'اكتب عنوان الموضوع هنا...',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // صندوق المحتوى
                TextField(
                  controller: _contentController,
                  maxLength: 800,
                  maxLines: 6,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'الوصف',
                    hintText: 'اكتب تفاصيل الوصف هنا...',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 100),
                      child: Icon(Icons.description),
                    ),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // زر النشر
                ElevatedButton(
                  onPressed: _isLoading ? null : _addPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('نشر المنشور', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}