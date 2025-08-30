import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../3_category/category_page.dart';
import '../3_category/study_card.dart';
import '../4_chat/chat_list_page.dart';
import '../5_my_page/my_page.dart';

// 페이지 전환을 위해 StatefulWidget으로 변경하고 콜백 함수를 추가했습니다.
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  String _userNickname = '사용자';
  bool _isLoading = true;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _buildPages(); // 페이지 목록을 빌드하는 메서드 호출
  }

  // 페이지 목록을 빌드하는 메서드입니다.
  // 닉네임이 변경되거나 페이지 이동이 필요할 때 호출됩니다.
  void _buildPages() {
    _pages = [
      HomePage(
        nickname: _userNickname,
        // HomePage에서 MyPage로 이동하기 위한 콜백 함수입니다.
        onNavigateToMyPage: () => _onNavTap(3),
      ),
      const CategoryPage(),
      const ChatListPage(),
      MyPage(onNicknameChanged: _updateNickname),
    ];
  }

  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userNickname = data['displayName'] as String? ?? '사용자';

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        Timestamp? lastLoginTimestamp = data['lastLogin'] as Timestamp?;
        DateTime lastLoginDate = lastLoginTimestamp?.toDate() ?? DateTime(1970);
        DateTime lastLoginDay = DateTime(lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);

        if (lastLoginDay.isBefore(today)) {
          await userRef.update({
            'growthIndex': FieldValue.increment(5),
            'lastLogin': Timestamp.now(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('☀️ 오늘 첫 로그인! +5 포인트를 획득했습니다.')),
            );
          }
        }
      }
    } catch (e) {
      print("사용자 데이터 로딩 실패: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _buildPages(); // 데이터 로딩 후 페이지를 다시 빌드합니다.
        });
      }
    }
  }

  void _updateNickname(String newNickname) {
    setState(() {
      _userNickname = newNickname;
      _buildPages(); // 닉네임 변경 시 페이지를 다시 빌드합니다.
    });
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

class HomePage extends StatefulWidget {
  final String nickname;
  // 페이지 이동을 위한 콜백 함수를 전달받습니다.
  final VoidCallback onNavigateToMyPage;

  const HomePage({
    super.key,
    required this.nickname,
    required this.onNavigateToMyPage,
  });

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
                // 버튼 클릭 시 전달받은 콜백 함수를 호출합니다.
                onPressed: widget.onNavigateToMyPage,
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
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryPage(initialFirstCategory: label),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.teal.withOpacity(0.1),
                child: Icon(icon, color: Colors.teal, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 16.0,
        runSpacing: 16.0,
        alignment: WrapAlignment.center,
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
                child: Text('스터디를 불러오지 못했습니다.\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
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
                  studyData: doc.data() as Map<String, dynamic>,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
