import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'applicant_list_page.dart';
// ### FIXED: 잘못된 import 경로를 올바르게 수정했습니다. ###
import '../3_category/category_data.dart';
import '../4_chat/chatting_page.dart';

// const 생성자에서 동적 값을 사용하던 오류를 해결하기 위해 const 키워드를 제거했습니다.
final List<Map<String, dynamic>> growthLevels = [
  {'icon': '💧', 'name': '물방울', 'points': '0 ~ 29'},
  {'icon': '🌱', 'name': '새싹', 'points': '30 ~ 69'},
  {'icon': '🌿', 'name': '잎사귀', 'points': '70 ~ 119'},
  {'icon': '🍀', 'name': '네잎클로버', 'points': '120 ~ 179'},
  {'icon': '🌸', 'name': '꽃망울', 'points': '180 ~ 249'},
  {'icon': '🌳', 'name': '어린나무', 'points': '250 ~ 329'},
  {'icon': '🌲', 'name': '성목', 'points': '330 ~ 419'},
  {'icon': '🏆', 'name': '트로피', 'points': '420 ~ 519'},
  {'icon': '🌟', 'name': '별', 'points': '520 ~ 629'},
  {'icon': '👑', 'name': '왕관', 'points': '630+'},
];

class MyPage extends StatefulWidget {
  final Function(String) onNicknameChanged;
  const MyPage({super.key, required this.onNicknameChanged});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _userStream = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots();
      _isLoading = false;
    });
  }

  Future<void> _showEditNicknameDialog(String currentNickname) async {
    final nicknameController = TextEditingController(text: currentNickname);
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('닉네임 변경'),
          content: TextField(
            controller: nicknameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "새 닉네임을 입력하세요"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('저장'),
              onPressed: () async {
                final newNickname = nicknameController.text.trim();
                if (newNickname.isNotEmpty && newNickname != currentNickname) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser!.uid)
                        .update({'displayName': newNickname});

                    if (mounted) {
                      widget.onNicknameChanged(newNickname);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('닉네임이 성공적으로 변경되었습니다.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류가 발생했습니다: $e')),
                      );
                    }
                  }
                }
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditInterestsDialog(List<String> currentInterests) async {
    List<String> selectedInterests = List.from(currentInterests);
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('관심 분야 수정'),
          content: SizedBox(
            width: double.maxFinite,
            child: _InterestSelector(
              // ### FIXED: 정의되지 않았던 변수 오류를 해결했습니다. ###
              categories: studyCategories,
              initialSelection: selectedInterests,
              onSelectionChanged: (selected) {
                selectedInterests = selected;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('저장'),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .update({'interests': selectedInterests});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('관심 분야가 저장되었습니다.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('저장에 실패했습니다: $e')),
                    );
                  }
                }
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  void _showPointSystemInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('✨ 포인트 시스템 안내'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text(
                  '스터디 활동에 참여하고 포인트를 모아 레벨을 올려보세요! 꾸준한 참여와 긍정적인 기여가 레벨업의 핵심입니다.',
                ),
                SizedBox(height: 20),
                Text('☀️ 기본 활동', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                Divider(),
                ListTile(leading: Icon(Icons.login_outlined, color: Colors.orange), title: Text('일일 첫 로그인'), trailing: Text("+5 점", style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: Icon(Icons.check_box_outlined, color: Colors.orange), title: Text('스터디 출석 체크'), trailing: Text("+10 점", style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: Icon(Icons.rule_folder_outlined, color: Colors.orange), title: Text('나의 할 일(To-do) 완료'), trailing: Text("+5 점", style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(height: 20),
                Text('🤝 협업 활동 (기여)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Divider(),
                ListTile(leading: Icon(Icons.link_outlined, color: Colors.blue), title: Text('스터디 자료 링크 공유'), trailing: Text("+10 점", style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: Icon(Icons.lightbulb_outline, color: Colors.blue), title: Text('다른 사람 질문에 답변'), trailing: Text("+10 점", style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: Icon(Icons.verified_outlined, color: Colors.blue), title: Text('내 답변이 채택될 경우'), trailing: Text("+20 점", style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(height: 20),
                Text('🏆 주요 성과 (보너스)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                Divider(),
                ListTile(leading: Icon(Icons.workspace_premium_outlined, color: Colors.purple), title: Text('스터디 성공적으로 완료'), trailing: Text("+100 점", style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: Icon(Icons.military_tech_outlined, color: Colors.purple), title: Text('주간 MVP로 선정'), trailing: Text("+50 점", style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: Icon(Icons.thumb_up_alt_outlined, color: Colors.purple), title: Text("'최고의 동료' 추천 받기"), trailing: Text("+50 점", style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(height: 20),
                Text('⚠️ 패널티', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                Divider(),
                ListTile(leading: Icon(Icons.directions_run_outlined, color: Colors.red), title: Text('스터디 중도 포기/강퇴'), trailing: Text("-50 점", style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(leading: Icon(Icons.no_meeting_room_outlined, color: Colors.red), title: Text('연속 3회 이상 미출석'), trailing: Text("-30 점", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('닫기'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showGrowthLevelGuideDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('🌱 성장 레벨 가이드'),
          content: SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(2),
              },
              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color.fromARGB(255, 240, 240, 240), borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))),
                  children: [
                    Padding(padding: EdgeInsets.all(10.0), child: Text('레벨', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(10.0), child: Text('이름', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(10.0), child: Text('필요 점수', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                ...growthLevels.map((level) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(10.0), child: Text(level['icon']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22))),
                    Padding(padding: const EdgeInsets.all(10.0), child: Center(child: Text(level['name']!, style: const TextStyle(height: 1.5)))),
                    Padding(padding: const EdgeInsets.all(10.0), child: Center(child: Text(level['points']!, style: const TextStyle(height: 1.5)))),
                  ],
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('닫기'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('마이페이지'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
            tabs: [
              Tab(text: '참여중'),
              Tab(text: '신청 현황'),
              Tab(text: '개설 스터디'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text("사용자 정보를 불러올 수 없습니다.")),
                  );
                }
                final userData = snapshot.data!.data()!;
                final nickname = userData['displayName'] ?? '사용자';
                final email = currentUser?.email ?? '이메일 정보 없음';
                final growthIndex = (userData['growthIndex'] as num?)?.toInt() ?? 0;
                final interests = List<String>.from(userData['interests'] ?? []);

                return Column(
                  children: [
                    _UserProfileWidget(
                      nickname: nickname,
                      email: email,
                      growthIndex: growthIndex,
                      onEditNickname: () => _showEditNicknameDialog(nickname),
                    ),
                    _InterestsSection(
                      interests: interests,
                      onEdit: () => _showEditInterestsDialog(interests),
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 1, thickness: 1),
            const Expanded(
              child: TabBarView(
                children: [
                  ActiveStudiesTab(),
                  AppliedStudiesTab(),
                  CreatedStudiesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthIndexWidget extends StatelessWidget {
  final int growthIndex;
  final VoidCallback onShowPointInfo;
  final VoidCallback onShowLevelGuide;


  const _GrowthIndexWidget({
    required this.growthIndex,
    required this.onShowPointInfo,
    required this.onShowLevelGuide,
  });

  @override
  Widget build(BuildContext context) {
    // const 생성자 오류 해결을 위해 const 키워드 제거
    final levels = [
      {'icon': '💧', 'name': '물방울', 'maxPoints': 30, 'color': Colors.blue},
      {'icon': '🌱', 'name': '새싹', 'maxPoints': 70, 'color': Colors.lightGreen},
      {'icon': '🌿', 'name': '잎사귀', 'maxPoints': 120, 'color': Colors.green},
      {'icon': '🍀', 'name': '네잎클로버', 'maxPoints': 180, 'color': Colors.teal},
      {'icon': '🌸', 'name': '꽃망울', 'maxPoints': 250, 'color': Colors.pinkAccent},
      {'icon': '🌳', 'name': '어린나무', 'maxPoints': 330, 'color': Colors.brown},
      // shade700이 const가 아니라서 발생한 오류 수정
      {'icon': '🌲', 'name': '성목', 'maxPoints': 420, 'color': Colors.green.shade700},
      {'icon': '🏆', 'name': '트로피', 'maxPoints': 520, 'color': Colors.amber},
      {'icon': '🌟', 'name': '별', 'maxPoints': 630, 'color': Colors.yellow.shade700},
      {'icon': '👑', 'name': '왕관', 'maxPoints': 1000, 'color': Colors.deepPurpleAccent},
    ];

    int currentLevelIndex = levels.indexWhere((level) => growthIndex < (level['maxPoints'] as int));
    if (currentLevelIndex == -1) currentLevelIndex = levels.length - 1;

    final currentLevel = levels[currentLevelIndex];
    final int minPoints = (currentLevelIndex == 0) ? 0 : (levels[currentLevelIndex - 1]['maxPoints'] as int);
    final int maxPoints = currentLevel['maxPoints'] as int;
    final double progress = (maxPoints == minPoints) ? 1.0 : (growthIndex - minPoints) / (maxPoints - minPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('성장 레벨', style: TextStyle(color: Colors.black54)),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onShowPointInfo,
                  borderRadius: BorderRadius.circular(20),
                  child: const Icon(Icons.help_outline, size: 16, color: Colors.grey),
                ),
              ],
            ),
            InkWell(
              onTap: onShowLevelGuide,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Text(
                  '${currentLevel['icon']} ${currentLevel['name']}',
                  style: TextStyle(color: currentLevel['color'] as Color, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(currentLevel['color'] as Color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('$growthIndex / $maxPoints', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      ],
    );
  }
}

class _UserProfileWidget extends StatelessWidget {
  final String nickname;
  final String email;
  final int growthIndex;
  final VoidCallback onEditNickname;

  const _UserProfileWidget({
    required this.nickname,
    required this.email,
    required this.growthIndex,
    required this.onEditNickname,
  });

  @override
  Widget build(BuildContext context) {
    final myPageState = context.findAncestorStateOfType<_MyPageState>()!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.teal.shade100,
            child: Text(
              nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, color: Colors.teal),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                _GrowthIndexWidget(
                  growthIndex: growthIndex,
                  onShowPointInfo: myPageState._showPointSystemInfoDialog,
                  onShowLevelGuide: myPageState._showGrowthLevelGuideDialog,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditNickname,
            icon: const Icon(Icons.edit_outlined, color: Colors.grey),
            tooltip: "닉네임 수정",
          ),
        ],
      ),
    );
  }
}

class _InterestsSection extends StatelessWidget {
  final List<String> interests;
  final VoidCallback onEdit;

  const _InterestsSection({required this.interests, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('나의 관심 분야', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('수정'),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (interests.isEmpty)
            const Text('아직 설정된 관심 분야가 없습니다.', style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: interests.map((interest) => Chip(
                label: Text(interest),
                backgroundColor: Colors.teal.withOpacity(0.1),
                side: BorderSide(color: Colors.teal.withOpacity(0.2)),
              )).toList(),
            ),
        ],
      ),
    );
  }
}

class _InterestSelector extends StatefulWidget {
  final Map<String, List<String>> categories;
  final List<String> initialSelection;
  final Function(List<String>) onSelectionChanged;

  const _InterestSelector({
    required this.categories,
    required this.initialSelection,
    required this.onSelectionChanged,
  });

  @override
  State<_InterestSelector> createState() => _InterestSelectorState();
}

class _InterestSelectorState extends State<_InterestSelector> {
  late String _selectedMainCategory;
  late List<String> _currentSelectedInterests;

  @override
  void initState() {
    super.initState();
    _selectedMainCategory = widget.categories.keys.first;
    _currentSelectedInterests = List.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: ListView.builder(
                itemCount: widget.categories.keys.length,
                itemBuilder: (context, index) {
                  final category = widget.categories.keys.elementAt(index);
                  final isSelected = category == _selectedMainCategory;
                  return ListTile(
                    title: Text(
                      category,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.teal : Colors.black87,
                      ),
                    ),
                    onTap: () => setState(() => _selectedMainCategory = category),
                    selected: isSelected,
                    selectedTileColor: Colors.teal.withOpacity(0.1),
                  );
                },
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: widget.categories[_selectedMainCategory]!.map((interest) {
                      final isSelected = _currentSelectedInterests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _currentSelectedInterests.add(interest);
                            } else {
                              _currentSelectedInterests.remove(interest);
                            }
                          });
                          widget.onSelectionChanged(_currentSelectedInterests);
                        },
                        selectedColor: Colors.teal.shade100,
                        checkmarkColor: Colors.teal,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('참여중인 스터디가 없습니다.'));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final study = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups)),
                title: Text(study['title'] ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('멤버 ${study['memberCount']}/${study['maxMembers']}'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChattingPage(studyId: doc.id, studyTitle: study['title'])));
                },
                trailing: const Icon(Icons.chat_bubble_outline),
              ),
            );
          }).toList(),
        );
      },
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('신청한 스터디가 없습니다.'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final String statusText;
            final Color statusColor;
            final Color statusTextColor;
            switch (status) {
              case 'accepted':
                statusText = '승인됨';
                statusColor = Colors.green.shade100;
                statusTextColor = Colors.green.shade800;
                break;
              case 'rejected':
                statusText = '거절됨';
                statusColor = Colors.red.shade100;
                statusTextColor = Colors.red.shade800;
                break;
              default:
                statusText = '대기중';
                statusColor = Colors.orange.shade100;
                statusTextColor = Colors.orange.shade800;
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(data['studyTitle'] ?? ''),
                trailing: Chip(
                  label: Text(statusText, style: TextStyle(fontWeight: FontWeight.w500, color: statusTextColor)),
                  backgroundColor: statusColor,
                  side: BorderSide.none,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class CreatedStudiesTab extends StatelessWidget {
  const CreatedStudiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('studies').where('leaderId', isEqualTo: currentUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('개설한 스터디가 없습니다.'));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final study = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(study['title'] ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('멤버 ${study['memberCount']}/${study['maxMembers']}'),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  label: const Text('신청자 관리'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ApplicantListPage(studyId: doc.id, studyTitle: doc['title']))),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

