import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http; // استيراد حزمة http
import 'dart:convert'; // لاستخدام jsonEncode

import '../../DataBaseSQLite/LocalSave.dart';
import '../../core/Statemanagement.dart';
import '../../Home.dart'; // ✅ استيراد MyApp

class Supin extends ConsumerStatefulWidget {
  const Supin({super.key});

  @override
  ConsumerState<Supin> createState() => _SupinState();
}

class _SupinState extends ConsumerState<Supin> {
  // تعريف الـ Controllers للتحكم في البيانات
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      final size = dispatcher.views.first.physicalSize;
      final ratio = dispatcher.views.first.devicePixelRatio;
      ref.read(screenWidthProvider.notifier).state = size.width / ratio;
      ref.read(screenHightProvider.notifier).state = size.height / ratio;
    });
  }

  // دالة التسجيل
  Future<void> _registerUser() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://207.154.255.210:8082/users/add'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userID": _usernameController.text, // استخدام اسم المستخدم كـ ID
          "username": _usernameController.text,
          "password": _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        // الحفظ محلياً بعد نجاح السيرفر
        await LocalUserStorage.saveUser(
          userId: _usernameController.text,
          name: _nameController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم التسجيل بنجاح! 🎉')),
          );

          // ✅ الانتقال لـ MyApp مع حذف كل الشاشات السابقة
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MyApp()),
                (route) => false,
          );
        }
      } else {
        throw Exception('فشل الاتصال: ${response.body}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 50),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'الاسم الكامل', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _usernameController,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]'))],
            decoration: InputDecoration(labelText: 'اسم المستخدم', prefixIcon: const Icon(Icons.alternate_email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: true, // إخفاء كلمة السر
            decoration: InputDecoration(labelText: 'كلمة السر', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isLoading ? null : _registerUser,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}