import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../DataBaseSQLite/LocalSave.dart';

class ScreenProfile extends ConsumerStatefulWidget {
  const ScreenProfile({super.key});

  @override
  ConsumerState<ScreenProfile> createState() => _ScreenProfileState();
}

class _ScreenProfileState extends ConsumerState<ScreenProfile> {
  String? _name;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await LocalUserStorage.getUser();
    if (mounted) {
      setState(() {
        _name = user?['name'] ?? 'بدون اسم';
        _userId = user?['userId'] ?? '---';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // صورة افتراضية
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.blue.shade100,
                child: Icon(Icons.person, size: 48, color: Colors.blue.shade700),
              ),

              const SizedBox(height: 20),

              // الاسم
              Text(
                _name!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // الـ ID
              Text(
                '@$_userId',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}