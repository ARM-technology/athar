import 'package:athar/Screen/Profile/Profile.dart';
import 'package:athar/Screen/Screen_Athar.dart';
import 'package:athar/Screen/Screen_CreatePost/Screen_Post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/Statemanagement.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {

  @override
  void initState() {
    super.initState();


    // 💡 الحل السحري: تأجيل التعديل ميكروسكوبياً حتى تنتهي الشجرة من البناء
    Future.microtask(() {

      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      final size = dispatcher.views.first.physicalSize;
      final ratio = dispatcher.views.first.devicePixelRatio;

      final double width = size.width / ratio;
      final double height = size.height / ratio;

      // الآن التحديث آمن 100% وبدون أي خطأ
      ref.read(screenWidthProvider.notifier).state = width;
      ref.read(screenHightProvider.notifier).state = height;
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = ref.watch(screenWidthProvider);
    double screenHight = ref.watch(screenHightProvider);

    double screenHightCounter = ref.watch(screenHightProvider);

    return MaterialApp(
      title: 'Athar',
      debugShowCheckedModeBanner: false,
      home:  Scaffold(
        body: Center(
          child: Column(children: [
           Expanded(child:  Padding(padding: EdgeInsetsGeometry.all(25),
            child: Container(
                width:screenWidth ,
                height: screenHightCounter *0.75,
              child: IndexedStack(
                index: ref.watch(counterProvider),
                children: [
                  ScreenAthar(),
                  ScreenPost(),
                  ScreenProfile(),
                ],
              ),
            )
            ),
           ),

          ],),
        ),

        bottomNavigationBar: Container(
          height:screenHightCounter *0.2 ,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [

              IconButton(
                onPressed: () {
                  ref.read(counterProvider.notifier).state =0;
                },
                icon: const Icon(Icons.home),
              ),

              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),

              IconButton(
                onPressed: () {
                  ref.read(counterProvider.notifier).state =1;
                },
                icon: const Icon(Icons.add_circle_outline),
              ),

              IconButton(
                onPressed: () {
                  ref.read(counterProvider.notifier).state =2;
                },
                icon: const Icon(Icons.person),
              ),

            ],
          ),
        ),


      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}