import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/Statemanagement.dart';
import 'PostWidgets.dart';
import 'PostModel.dart';
import 'FeedService.dart';

// Provider يجلب البوستات من السيرفر
final globalFeedProvider = FutureProvider<List<PostModel>>((ref) async {
  return await FeedService.getGlobalFeed();
});

class ScreenAthar extends ConsumerStatefulWidget {
  const ScreenAthar({super.key});

  @override
  ConsumerState<ScreenAthar> createState() => _ScreenAtharState();
}

class _ScreenAtharState extends ConsumerState<ScreenAthar> {

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

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(globalFeedProvider);

    return Scaffold(
      body: feedAsync.when(

        // جاري التحميل
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        // في خطأ
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'حدث خطأ',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(globalFeedProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),

        // البوستات وصلت
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد منشورات بعد',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            // السحب للأسفل يعيد الجلب
            onRefresh: () async => ref.refresh(globalFeedProvider),
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return AllWidgets.postWidget(
                  name: post.username,
                  userId: post.userID,
                  title: post.title,
                  content: post.content,
                  likes: post.likes,
                  dislikes: post.dislikes,
                  comments: post.comments,
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}