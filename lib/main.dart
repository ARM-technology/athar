import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'DataBaseSQLite/LocalSave.dart'; // تأكد من مسار ملف التخزين
import 'Home.dart'; // هنا يوجد كلاس MyApp الخاص بك
import 'Screen/LogInAndSupIn/SupIn.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التحقق من وجود المستخدم محلياً
  bool userExists = await LocalUserStorage.isUserExists();

  runApp(
    ProviderScope(
      // إذا كان المستخدم موجوداً، نفتح MyApp مباشرة
      // إذا لم يكن موجوداً، نفتح Supin
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: userExists ? const MyApp() : const Supin(),
      ),
    ),
  );
}