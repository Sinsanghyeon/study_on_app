import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/home_page.dart'; // home_page.dart 파일 경로를 확인해주세요.

// ===================================================================
// --- 1. 앱 시작점 및 Firebase 초기화 ---
// ===================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const StudyOnApp());
}

class StudyOnApp extends StatelessWidget {
  const StudyOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스터디 온',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
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
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ===================================================================
// --- 2. 인증 상태 관리 ---
// ===================================================================
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

// ===================================================================
// --- 3. 로그인 페이지 ---
// ===================================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message = '로그인에 실패했습니다.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = '이메일 또는 비밀번호가 올바르지 않습니다.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, color: Colors.teal.shade300, size: 80),
                    const SizedBox(height: 12),
                    const Text('스터디 온', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(hintText: '이메일 주소', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(hintText: '비밀번호', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                      child: const Text('로그인'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage())),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        minimumSize: const Size(double.infinity, 52),
                        side: BorderSide(color: Colors.teal.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// --- 4. 회원가입 페이지 (현재 Firebase 구조에 맞게 수정됨) ---
// ===================================================================
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isLoadingInterests = true;
  Map<String, dynamic> _interestCategoryMap = {};
  List<String> _selectedInterests = [];

  @override
  void initState() {
    super.initState();
    _loadInterestOptionsFromFirebase();
  }

  Future<void> _loadInterestOptionsFromFirebase() async {
    try {
      final doc = await _firestore.collection('app_config').doc('interest_options').get();
      if (doc.exists && doc.data() != null) {
        // 'categoryMap' 필드를 찾는 대신, 문서의 전체 데이터를 그대로 사용
        _interestCategoryMap = doc.data()!;
      }
    } catch (e) {
      print("관심사 옵션 로딩 실패: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInterests = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 필드를 입력해주세요.')));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'phone': phone,
          'displayName': user.email?.split('@')[0],
          'created_at': Timestamp.now(),
          'interests': _selectedInterests,
        });

        await _auth.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다! 로그인해주세요.')));
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = '회원가입에 실패했습니다.';
      if (e.code == 'weak-password') message = '비밀번호는 6자리 이상이어야 합니다.';
      else if (e.code == 'email-already-in-use') message = '이미 사용 중인 이메일입니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: emailController, decoration: const InputDecoration(labelText: '이메일 주소', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: '휴대폰 번호 (- 제외)', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 16),
                TextField(controller: confirmPasswordController, decoration: const InputDecoration(labelText: '비밀번호 확인', border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 24),

                const Text('관심 분야를 선택해주세요 (복수선택 가능)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                _isLoadingInterests
                    ? const Center(child: CircularProgressIndicator())
                    : _buildInterestSelectionUI(),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                  child: const Text('회원가입 완료'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildInterestSelectionUI() {
    if (_interestCategoryMap.isEmpty) {
      return const Text('관심사 정보를 불러올 수 없습니다.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _interestCategoryMap.entries.map((entry) {
        final firstCategory = entry.key;
        final secondCatList = entry.value as List;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[$firstCategory]', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: secondCatList.map((interest) {
                  final interestStr = interest.toString();
                  final isSelected = _selectedInterests.contains(interestStr);
                  return FilterChip(
                    label: Text(interestStr),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interestStr);
                        } else {
                          _selectedInterests.remove(interestStr);
                        }
                      });
                    },
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}