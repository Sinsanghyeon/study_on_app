import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'category_page.dart';
import 'chat_list_page.dart';
import 'my_page.dart';
import '../widgets/study_card.dart';

// ===================================================================
// --- 1. 메인 프레임 (하단 탭 바) ---
// ===================================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  String _userNickname = '사용자';
  bool _isLoading = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _pages = [
      HomePage(nickname: _userNickname),
      const CategoryPage(),
      const ChatListPage(),
      MyPage(onNicknameChanged: _updateNickname),
    ];
  }

  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _rebuildPages();
      });
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userNickname = data['displayName'] as String? ?? '사용자';
      }
    } catch (e) {
      print("사용자 데이터 로딩 실패: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _rebuildPages();
        });
      }
    }
  }

  void _updateNickname(String newNickname) {
    setState(() {
      _userNickname = newNickname;
      _rebuildPages();
    });
  }

  void _rebuildPages() {
    _pages[0] = HomePage(nickname: _userNickname);
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '탐색'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }
}

// ===================================================================
// --- 2. 홈 탭 화면 ---
// ===================================================================
class HomePage extends StatefulWidget {
  final String nickname;
  const HomePage({super.key, required this.nickname});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  List<String> _userInterests = [];
  bool _isLoadingInterests = true;

  @override
  void initState() {
    super.initState();
    _loadUserInterests();
  }

  Future<void> _loadUserInterests() async {
    if (currentUser == null) {
      setState(() => _isLoadingInterests = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('interests')) {
        final interestsData = userDoc.data()!['interests'] as List;
        _userInterests = interestsData.map((item) => item.toString()).toList();
      }
    } catch (e) {
      print("관심사 로딩 실패: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingInterests = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildSectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
    }

    return Scaffold(
      appBar: AppBar(toolbarHeight: 0, backgroundColor: Colors.white, elevation: 0),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserInterests();
        },
        child: ListView(
          children: [
            _HomeHeader(nickname: widget.nickname),
            const SizedBox(height: 24),
            buildSectionTitle("🎯 카테고리 바로가기"),
            const _CategoryShortcuts(),
            const SizedBox(height: 24),
            buildSectionTitle("⏰ 마감 임박 스터디"),
            _StudyHorizontalList(
              query: FirebaseFirestore.instance
                  .collection('studies')
                  .where('isRecruiting', isEqualTo: true)
                  .orderBy('deadline')
                  .limit(10),
            ),
            const SizedBox(height: 24),
            buildSectionTitle("✨ 신규 스터디"),
            _StudyHorizontalList(
              query: FirebaseFirestore.instance
                  .collection('studies')
                  .where('isRecruiting', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .limit(10),
            ),
            const SizedBox(height: 24),
            buildSectionTitle("👍 ${widget.nickname}님을 위한 추천 스터디"),
            _buildRecommendedStudies(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedStudies() {
    if (_isLoadingInterests) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }

    if (_userInterests.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('아직 관심사를 설정하지 않으셨네요!'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // [MODIFIED] const 키워드 제거
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MyPage(onNicknameChanged: (_){},)));
                },
                child: const Text('관심사 설정하러 가기'),
              )
            ],
          ),
        ),
      );
    }

    return _StudyHorizontalList(
      query: FirebaseFirestore.instance
          .collection('studies')
          .where('isRecruiting', isEqualTo: true)
          .where('category', whereIn: _userInterests)
          .limit(10),
    );
  }
}

// ===================================================================
// --- 3. 홈 화면의 하위 위젯들 ---
// ===================================================================

class _HomeHeader extends StatelessWidget {
  final String nickname;
  const _HomeHeader({required this.nickname});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('스터디 온', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                IconButton(
                  tooltip: '로그아웃',
                  icon: const Icon(Icons.logout, color: Colors.grey),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("$nickname님, 성장하는 하루 보내세요!", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryPage()));
              },
              decoration: InputDecoration(
                hintText: '어떤 스터디를 찾고 계신가요?',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _CategoryShortcuts extends StatelessWidget {
  const _CategoryShortcuts();

  @override
  Widget build(BuildContext context) {
    final shortcuts = {
      '취업・이직': Icons.work_outline,
      '외국어': Icons.translate,
      '자격증': Icons.article_outlined,
      'IT・SW': Icons.code,
    };

    Widget buildShortcut(String label, IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryPage(initialFirstCategory: label),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.teal.withOpacity(0.1),
                child: Icon(icon, color: Colors.teal, size: 28),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: shortcuts.entries.map((entry) {
          return buildShortcut(entry.key, entry.value);
        }).toList(),
      ),
    );
  }
}

class _StudyHorizontalList extends StatelessWidget {
  final Query query;
  const _StudyHorizontalList({required this.query});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('스터디를 불러오지 못했습니다.\n(Firestore 색인 문제일 수 있습니다)\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('해당 스터디가 없습니다.'));
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              return SizedBox(
                width: 280,
                child: StudyCard(
                  studyId: doc.id,
                  study: doc.data() as Map<String, dynamic>,
                ),
              );
            },
          );
        },
      ),
    );
  }
}