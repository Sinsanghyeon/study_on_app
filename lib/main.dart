import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
// ERROR FIXED: 한글 날짜/시간 포맷을 사용하기 위해 intl 패키지를 import 합니다.
import 'package:intl/date_symbol_data_local.dart';

import 'models/1_login/login_page.dart';
import 'models/2_home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ERROR FIXED: 앱이 시작될 때 한글 로케일의 날짜 형식을 초기화합니다.
  // 이 코드를 추가하면 LocaleDataException 오류가 해결됩니다.
  await initializeDateFormatting('ko_KR');

  await NaverMapSdk.instance.initialize(
      clientId: 'j7uw9sf77t', // 발급받은 Client ID
      onAuthFailed: (ex) {
        print("********* 네이버맵 인증오류 : $ex *********");
      });

  await Firebase.initializeApp();
  runApp(const StudyOnApp());
}

class StudyOnApp extends StatelessWidget {
  const StudyOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '스터디 온',
      theme: ThemeData(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MainPage();
        }
        return const LoginPage();
      },
    );
  }
}
