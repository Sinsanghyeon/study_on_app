import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const StudyOnApp());
}

// =================================================================
// --- 1. 앱 시작 및 인증 상태 관리 ---
// =================================================================

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

// =================================================================
// --- 2. 로그인 / 회원가입 페이지 (login.dart 기반) ---
// =================================================================

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
    } on FirebaseAuthException catch (e) {
      String message = '로그인에 실패했습니다.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = '이메일 또는 비밀번호가 올바르지 않습니다.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
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
                    const Icon(Icons.school, color: Colors.blue, size: 80),
                    const SizedBox(height: 12),
                    const Text('스터디 온', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(hintText: '이메일 주소', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(hintText: '비밀번호', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('로그인'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage())),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
        });

        // ✅ FIX: 회원가입 성공 후 로그인 페이지로 돌아가도록 로그아웃 처리
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
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
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: '이메일 주소', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: '휴대폰 번호 (- 제외)', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  TextField(controller: passwordController, decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()), obscureText: true),
                  const SizedBox(height: 16),
                  TextField(controller: confirmPasswordController, decoration: const InputDecoration(labelText: '비밀번호 확인', border: OutlineInputBorder()), obscureText: true),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: _isLoading ? null : _signUp, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('회원가입 완료')),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

// =================================================================
// --- 3. 메인 페이지 (하단 네비게이션 바) ---
// =================================================================

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const StudyCategoryPage(),
    const MyPage(),
  ];

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '스터디 탐색'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 스터디'),
        ],
      ),
    );
  }
}

// =================================================================
// --- 4. 홈 페이지 (
// home.dart 기반) ---
// =================================================================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            const Icon(Icons.school, color: Colors.teal),
            const SizedBox(width: 8),
            Text('스터디 온', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800])),
          ],
        ),
        actions: [
          IconButton(tooltip: '로그아웃', icon: const Icon(Icons.logout, color: Colors.grey), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${currentUser?.email?.split('@')[0] ?? '사용자'}님,", style: const TextStyle(fontSize: 18, color: Colors.white)),
                const Text("어떤 스터디를 찾고 계신가요?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("🔥 최근 등록된 스터디", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('studies').orderBy('createdAt', descending: true).limit(3).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Text('아직 스터디가 없습니다.');
              return Column(
                children: snapshot.data!.docs.map((doc) => StudyCard(studyId: doc.id, study: doc.data() as Map<String, dynamic>)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =================================================================
// --- 5. 스터디 탐색 페이지 (catagory.dart 기반, 모든 기능 포함) ---
// =================================================================

class StudyCategoryPage extends StatefulWidget {
  const StudyCategoryPage({super.key});
  @override
  State<StudyCategoryPage> createState() => _StudyCategoryPageState();
}

class _StudyCategoryPageState extends State<StudyCategoryPage> {
  String selectedSort = '인기순';
  DateTimeRange? dateRange;
  String selectedCity = '서울';
  String selectedDistrict = '강남구';
  String? selectedDong;
  String selectedMainCategory = '어학';
  List<String> selectedSubCategories = [];

  final List<String> sortOptions = ['인기순', '최근등록순', '마감임박순'];
  final Map<String, List<String>> districtMap = {'서울': ['강남구', '서초구'], '부산': ['해운대구']};
  final Map<String, List<String>> dongMap = {'강남구': ['역삼동', '삼성동'], '서초구': ['반포동'], '해운대구': ['우동', '중동']};
  final Map<String, Map<String, List<String>>> categoryMap = {
    '어학': {
      '시험용': ['TOEIC(토익)', 'TOEFL(토플)', 'OPIC(오픽)', 'TOEIC Speaking(토익 스피킹)', 'G-TELP(지텔프)', 'JLPT(일본어 능력시험)'],
      '회화': ['영어 회화', '일본어 회화', '중국어 회화'],
    },
    '자격증': {
      '공학계열': ['정보처리기사', '전기기사', '산업안전기사', '건축기사', '토목기사', '기계설계기사'],
      '경영·회계계열': ['전산회계 1급', '전산세무 2급', 'ERP 정보관리사', '회계관리 1급', '증권투자상담사'],
    },
    '면접': {
      '대기업': ['삼성', 'LG', '카카오'],
      '공기업': ['한전', '가스공사'],
      '공무원': ['경찰공무원', '소방공무원', '교육행정직'],
    },
  };

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateBottom) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('종류별', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ExpansionPanelList.radio(
                      initialOpenPanelValue: selectedMainCategory,
                      children: categoryMap.entries.map((entry) {
                        final mainCat = entry.key;
                        final secondMap = entry.value;
                        return ExpansionPanelRadio(
                          value: mainCat,
                          headerBuilder: (ctx, isOpen) => ListTile(title: Text('[1차] $mainCat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          body: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: secondMap.entries.map((secondEntry) {
                              final secondCat = secondEntry.key;
                              return ExpansionTile(
                                title: Text('[2차] $secondCat', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal)),
                                children: secondEntry.value.map((third) {
                                  final isSelected = selectedSubCategories.contains(third);
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 32.0),
                                    child: ListTile(
                                      dense: true,
                                      title: Text('→ $third'),
                                      trailing: isSelected ? const Icon(Icons.check, color: Colors.teal) : null,
                                      onTap: () {
                                        setStateBottom(() {
                                          if (isSelected) {
                                            selectedSubCategories.remove(third);
                                          } else {
                                            selectedSubCategories.add(third);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('기간별', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(dateRange == null ? '날짜를 선택하세요' : '${DateFormat('yyyy-MM-dd').format(dateRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(dateRange!.end)}'),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDateRangePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (picked != null) setStateBottom(() => dateRange = picked);
                        },
                        child: const Text('날짜 선택'),
                      )
                    ]),
                    const SizedBox(height: 24),
                    const Text('지역별', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCity,
                          items: districtMap.keys.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
                          onChanged: (val) => setStateBottom(() {
                            selectedCity = val!;
                            selectedDistrict = districtMap[selectedCity]!.first;
                            selectedDong = dongMap[selectedDistrict]?.first;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedDistrict,
                          items: districtMap[selectedCity]!.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (val) => setStateBottom(() {
                            selectedDistrict = val!;
                            selectedDong = dongMap[selectedDistrict]?.first;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (dongMap[selectedDistrict] != null)
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedDong,
                            items: dongMap[selectedDistrict]!.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (val) => setStateBottom(() => selectedDong = val),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      child: const Text('설정 완료'),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddStudySheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '5');
    // ... (기타 컨트롤러 및 변수 선언)

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setStateBottom) => SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('스터디 추가', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '모임명')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '소개')),
                TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: '모집인원'), keyboardType: TextInputType.number),
                // ... (기타 상세 UI 필드들)
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (titleCtrl.text.isEmpty || currentUser == null) return;

                    final studyData = {
                      'title': titleCtrl.text,
                      'desc': descCtrl.text,
                      'maxMembers': int.tryParse(maxCtrl.text) ?? 5,
                      'leaderId': currentUser.uid,
                      'leaderEmail': currentUser.email,
                      'members': [currentUser.uid],
                      'memberEmails': [currentUser.email],
                      'memberCount': 1,
                      'isRecruiting': true,
                      'createdAt': FieldValue.serverTimestamp(),
                      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      'type': '온라인', // 예시
                    };
                    await FirebaseFirestore.instance.collection('studies').add(studyData);
                    if(mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: const Text('추가'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스터디 탐색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: selectedSort,
                  onChanged: (val) => setState(() => selectedSort = val!),
                  items: sortOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                ),
                TextButton(onPressed: _showFilterBottomSheet, child: const Text('필터', style: TextStyle(fontSize: 16))),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('studies').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("등록된 스터디가 없습니다."));
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: snapshot.data!.docs.map((doc) => StudyCard(studyId: doc.id, study: doc.data() as Map<String, dynamic>)).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudySheet,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class StudyDetailPage extends StatelessWidget {
  final String studyId;
  final Map<String, dynamic> studyData;
  const StudyDetailPage({super.key, required this.studyId, required this.studyData});

  void _applyForStudy(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (studyData['members'] != null && (studyData['members'] as List).contains(currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이미 참여중인 스터디입니다.")));
      return;
    }

    final existingApplication = await FirebaseFirestore.instance
        .collection('applications')
        .where('studyId', isEqualTo: studyId)
        .where('applicantId', isEqualTo: currentUser.uid)
        .limit(1).get();

    if (existingApplication.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이미 신청한 스터디입니다.")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스터디 신청'),
        content: const Text('이 스터디에 정말 신청하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('applications').add({
                  'studyId': studyId,
                  'studyTitle': studyData['title'],
                  'applicantId': currentUser.uid,
                  'applicantEmail': currentUser.email,
                  'status': 'pending',
                  'appliedAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (completionCtx) => AlertDialog(
                      title: const Text('신청 완료'),
                      content: const Text('스터디 신청이 완료되었습니다.'),
                      actions: [TextButton(onPressed: () {Navigator.pop(completionCtx);Navigator.pop(context);}, child: const Text('확인'))],
                    ),
                  );
                }
              } catch (e) { /* 오류 처리 */ }
            },
            child: const Text('신청'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(studyData['title'] ?? '스터디 상세')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(studyData['title'] ?? '', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(studyData['desc'] ?? '', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 40),
            Text('리더: ${studyData['leaderEmail'] ?? '정보 없음'}'),
            const SizedBox(height: 8),
            Text('모집 현황: ${studyData['memberCount'] ?? 1} / ${studyData['maxMembers'] ?? '?'}'),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("스터디 신청하기"),
          onPressed: () => _applyForStudy(context),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
      ),
    );
  }
}

// =================================================================
// --- 6. 내 스터디 페이지 ---
// =================================================================

class MyPage extends StatelessWidget {
  const MyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 스터디'),
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: '내가 개설한 스터디 관리',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyManagementPage())),
            )
          ],
          bottom: const TabBar(tabs: [Tab(text: '신청 현황'), Tab(text: '참여중인 스터디')]),
        ),
        body: const TabBarView(children: [AppliedStudiesTab(), ActiveStudiesTab()]),
      ),
    );
  }
}

class AppliedStudiesTab extends StatelessWidget {
  const AppliedStudiesTab({super.key});
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('applications').where('applicantId', isEqualTo: currentUser.uid).orderBy('appliedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('신청한 스터디가 없습니다.'));
        return ListView(
          padding: const EdgeInsets.all(8),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(data['studyTitle'] ?? ''),
                trailing: Chip(
                  label: Text(data['status'] ?? ''),
                  backgroundColor: data['status'] == 'accepted' ? Colors.green[100] : (data['status'] == 'rejected' ? Colors.red[100] : Colors.orange[100]),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ActiveStudiesTab extends StatelessWidget {
  const ActiveStudiesTab({super.key});
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('studies').where('members', arrayContains: currentUser.uid).snapshots(),
      builder: (context, studySnapshot) {
        if (studySnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!studySnapshot.hasData || studySnapshot.data!.docs.isEmpty) return const Center(child: Text('참여중인 스터디가 없습니다.'));

        return ListView(
          padding: const EdgeInsets.all(8),
          children: studySnapshot.data!.docs.map((doc) {
            final studyData = doc.data() as Map<String, dynamic>;
            final isRecruiting = studyData['isRecruiting'] ?? true;
            return Card(
              child: ListTile(
                leading: Icon(isRecruiting ? Icons.hourglass_top_rounded : Icons.chat_bubble, color: Colors.teal),
                title: Text(studyData['title']),
                subtitle: Text(isRecruiting ? "모집중 (${studyData['memberCount']}/${studyData['maxMembers']})" : "모집 완료! 채팅방으로 이동"),
                onTap: () {
                  if (isRecruiting) {
                    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('알림'), content: const Text('모집이 완료되어야 채팅방 입장이 가능합니다.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))]));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChattingPage(studyId: doc.id, studyTitle: studyData['title'])));
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class StudyManagementPage extends StatelessWidget {
  const StudyManagementPage({super.key});
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));

    return Scaffold(
      appBar: AppBar(title: const Text('스터디 관리')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('studies').where('leaderId', isEqualTo: currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text('개설한 스터디가 없습니다.'));

          return ListView(
            padding: const EdgeInsets.all(8),
            children: snapshot.data!.docs.map((doc) => Card(
              child: ListTile(
                title: Text(doc['title']),
                subtitle: const Text('신청자 관리하기'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ApplicantListPage(studyId: doc.id, studyTitle: doc['title']))),
              ),
            )).toList(),
          );
        },
      ),
    );
  }
}

class ApplicantListPage extends StatelessWidget {
  final String studyId;
  final String studyTitle;
  const ApplicantListPage({super.key, required this.studyId, required this.studyTitle});

  Future<void> _updateApplicationStatus(BuildContext context, String docId, String status, String applicantId, String applicantEmail) async {
    final firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();

    batch.update(firestore.collection('applications').doc(docId), {'status': status});

    if (status == 'accepted') {
      final studyRef = firestore.collection('studies').doc(studyId);
      final studyDoc = await studyRef.get();
      if (!studyDoc.exists) return;

      final studyData = studyDoc.data()!;
      final maxMembers = studyData['maxMembers'];
      final newMemberCount = (studyData['memberCount'] ?? 0) + 1;

      batch.update(studyRef, {
        'members': FieldValue.arrayUnion([applicantId]),
        'memberEmails': FieldValue.arrayUnion([applicantEmail]),
        'memberCount': FieldValue.increment(1),
      });

      if (newMemberCount >= maxMembers) {
        batch.update(studyRef, {'isRecruiting': false});
      }
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신청을 $status 처리했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$studyTitle 신청자 목록')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('applications').where('studyId', isEqualTo: studyId).where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text('대기중인 신청자가 없습니다.'));

          return ListView(
            padding: const EdgeInsets.all(8),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final applicantId = data['applicantId'];
              final applicantEmail = data['applicantEmail'];

              return Card(
                child: ListTile(
                  title: Text(applicantEmail ?? '정보 없음'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check, color: Colors.green), tooltip: '수락', onPressed: () => _updateApplicationStatus(context, doc.id, 'accepted', applicantId, applicantEmail)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), tooltip: '거절', onPressed: () => _updateApplicationStatus(context, doc.id, 'rejected', applicantId, applicantEmail)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// =================================================================
// --- 7. 채팅 페이지 (chatting.dart 기반) ---
// =================================================================
class ChattingPage extends StatefulWidget {
  final String studyId;
  final String studyTitle;
  const ChattingPage({super.key, required this.studyId, required this.studyTitle});

  @override
  State<ChattingPage> createState() => _ChattingPageState();
}

class _ChattingPageState extends State<ChattingPage> {
  final _messageController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _currentUser == null) return;

    _firestore.collection('chats').doc(widget.studyId).collection('messages').add({
      'senderId': _currentUser!.uid,
      'senderEmail': _currentUser!.email,
      'message': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studyTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: "참여 멤버 보기",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("스터디 멤버"),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('studies').doc(widget.studyId).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final members = List<String>.from(snapshot.data!.get('memberEmails') ?? []);
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: members.length,
                            itemBuilder: (context, index) => ListTile(title: Text(members[index])),
                          );
                        },
                      ),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("닫기"))],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('chats').doc(widget.studyId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("아직 메시지가 없습니다."));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == _currentUser!.uid;
                    final senderEmail = data['senderEmail'] as String? ?? 'U';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                              child: Text(senderEmail.split('@')[0], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                          Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.teal : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(data['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(offset: const Offset(0, -1), blurRadius: 2, color: Colors.grey.withOpacity(0.1))]),
            padding: EdgeInsets.only(left: 16, right: 8, bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration.collapsed(hintText: "메시지를 입력하세요"),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.teal), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}