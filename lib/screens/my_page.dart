import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chatting_page.dart';

// ===================================================================
// --- 1. 마이페이지 메인 화면 ---
// ===================================================================
class MyPage extends StatefulWidget {
  final Function(String) onNicknameChanged;
  const MyPage({super.key, required this.onNicknameChanged});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _nickname = '사용자';
  String _email = '';
  int _growthIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _nickname = data['displayName'] ?? currentUser!.email?.split('@')[0] ?? '사용자';
          _email = currentUser!.email ?? '이메일 정보 없음';
          _growthIndex = (data['growthIndex'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      print("사용자 정보 로딩 실패: $e");
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditNicknameDialog() async {
    final nicknameController = TextEditingController(text: _nickname);

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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('저장'),
              onPressed: () async {
                final newNickname = nicknameController.text.trim();
                if (newNickname.isNotEmpty && newNickname != _nickname) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser!.uid)
                        .update({'displayName': newNickname});

                    setState(() {
                      _nickname = newNickname;
                    });

                    widget.onNicknameChanged(newNickname);

                    if (mounted) {
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
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showGrowthIndexInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        const pointTextStylePositive = TextStyle(color: Colors.blue, fontWeight: FontWeight.bold);
        const pointTextStyleNegative = TextStyle(color: Colors.red, fontWeight: FontWeight.bold);

        return AlertDialog(
          title: const Text('🌱 성장 지수란?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                  '성장 지수는 스터디 활동에 대한 신뢰도와 성실도를 나타내는 지표입니다. 꾸준한 활동으로 포인트를 모아 숲으로 성장시켜보세요!',
                ),

                const SizedBox(height: 20),
                const Text('🌳 성장 단계 안내', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                const ListTile(
                  leading: Text('🌱', style: TextStyle(fontSize: 20)),
                  title: Text('씨앗 단계'),
                  trailing: Text("0 ~ 49 점"),
                ),
                const ListTile(
                  leading: Text('🌿', style: TextStyle(fontSize: 20)),
                  title: Text('새싹 단계'),
                  trailing: Text("50 ~ 149 점"),
                ),
                const ListTile(
                  leading: Text('🌳', style: TextStyle(fontSize: 20)),
                  title: Text('나무 단계'),
                  trailing: Text("150 ~ 299 점"),
                ),
                const ListTile(
                  leading: Text('🌲', style: TextStyle(fontSize: 20)),
                  title: Text('숲 단계'),
                  trailing: Text("300 점 이상"),
                ),

                const SizedBox(height: 20),
                const Text('✨ 꾸준한 활동으로 포인트를 쌓아보세요!', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.login, color: Colors.green),
                  title: Text('매일 최초 접속 시'),
                  trailing: Text("+1 점", style: pointTextStylePositive),
                ),
                const ListTile(
                  leading: Icon(Icons.check_box, color: Colors.green),
                  title: Text('할 일(To-do) 1개 완료 시'),
                  trailing: Text("+2 점", style: pointTextStylePositive),
                ),
                const ListTile(
                  leading: Icon(Icons.chat, color: Colors.green),
                  title: Text('스터디 채팅 참여 (하루 최대 5점)'),
                  trailing: Text("+1 점", style: pointTextStylePositive),
                ),

                const SizedBox(height: 20),
                const Text('🎉 주요 활동 보상', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.auto_awesome, color: Colors.blue),
                  title: Text('스터디 성공적으로 완료'),
                  trailing: Text("+20 점", style: pointTextStylePositive),
                ),
                const ListTile(
                  leading: Icon(Icons.thumb_up_alt, color: Colors.blue),
                  title: Text('스터디원에게 좋은 평가 받기'),
                  trailing: Text("+10 점", style: pointTextStylePositive),
                ),

                const SizedBox(height: 20),
                const Text('👎 포인트가 차감되는 경우', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.directions_run, color: Colors.red),
                  title: Text('스터디 중도 포기 또는 강퇴'),
                  trailing: Text("-20 점", style: pointTextStyleNegative),
                ),
                const ListTile(
                  leading: Icon(Icons.thumb_down_alt, color: Colors.red),
                  title: Text('스터디원에게 나쁜 평가 받기'),
                  trailing: Text("-15 점", style: pointTextStyleNegative),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
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
            indicatorColor: Colors.teal,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            splashFactory: NoSplash.splashFactory,
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
            _buildUserProfile(context),
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

  Widget _buildGrowthIndex() {
    String levelName;
    String levelIcon;
    Color progressColor;
    int currentLevelMaxPoint;
    int currentLevelMinPoint;

    if (_growthIndex < 50) {
      levelName = '씨앗 단계';
      levelIcon = '🌱';
      progressColor = Colors.brown;
      currentLevelMinPoint = 0;
      currentLevelMaxPoint = 50;
    } else if (_growthIndex < 150) {
      levelName = '새싹 단계';
      levelIcon = '🌿';
      progressColor = Colors.green;
      currentLevelMinPoint = 50;
      currentLevelMaxPoint = 150;
    } else if (_growthIndex < 300) {
      levelName = '나무 단계';
      levelIcon = '🌳';
      progressColor = Colors.teal;
      currentLevelMinPoint = 150;
      currentLevelMaxPoint = 300;
    } else {
      levelName = '숲 단계';
      levelIcon = '🌲';
      progressColor = Colors.deepPurple;
      currentLevelMinPoint = 300;
      currentLevelMaxPoint = 500;
    }

    final double progress =
    (currentLevelMaxPoint == currentLevelMinPoint) ? 1.0 : (_growthIndex - currentLevelMinPoint) / (currentLevelMaxPoint - currentLevelMinPoint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('성장 지수', style: TextStyle(color: Colors.black54)),
            Text(
              '$levelIcon $levelName',
              style: TextStyle(
                color: progressColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress.isNaN ? 0 : progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 6,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
              '$_growthIndex / $currentLevelMaxPoint',
              style: const TextStyle(fontSize: 12, color: Colors.black54)
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.teal.shade100,
            child: Text(
              _nickname.isNotEmpty ? _nickname[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, color: Colors.teal),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nickname,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                InkWell(
                  onTap: _showGrowthIndexInfoDialog,
                  child: _buildGrowthIndex(),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showEditNicknameDialog,
            icon: const Icon(Icons.edit_outlined, color: Colors.grey),
            tooltip: "프로필 수정",
          )
        ],
      ),
    );
  }
}

class ActiveStudiesTab extends StatelessWidget {
  const ActiveStudiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    // ... 이하 코드 변경 없음 ...
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
                leading: CircleAvatar(child: const Icon(Icons.groups)),
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
    // ... 이하 코드 변경 없음 ...
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('applications').where('applicantId', isEqualTo: currentUser.uid).orderBy('appliedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('신청한 스터디가 없습니다.'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final Color statusColor;
            final Color statusTextColor;
            switch (status) {
              case 'accepted':
                statusColor = Colors.green.shade100;
                statusTextColor = Colors.green.shade800;
                break;
              case 'rejected':
                statusColor = Colors.red.shade100;
                statusTextColor = Colors.red.shade800;
                break;
              default:
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
                  label: Text(status, style: TextStyle(fontWeight: FontWeight.w500, color: statusTextColor)),
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
    // ... 이하 코드 변경 없음 ...
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('studies').where('leaderId', isEqualTo: currentUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('개설한 스터디가 없습니다.'));

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

class ApplicantListPage extends StatelessWidget {
  final String studyId;
  final String studyTitle;
  const ApplicantListPage({super.key, required this.studyId, required this.studyTitle});

  // [MODIFIED] 신청 수락 시 신청자의 growthIndex를 5점 올려주도록 수정
  Future<void> _updateApplicationStatus(BuildContext context, String docId, String status, String applicantId, String applicantNickname) async {
    final firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();

    // 1. 신청서의 상태를 'accepted'로 변경
    batch.update(firestore.collection('applications').doc(docId), {'status': status});

    if (status == 'accepted') {
      // 2. 스터디 문서에 멤버 정보 추가
      final studyRef = firestore.collection('studies').doc(studyId);
      batch.update(studyRef, {
        'members': FieldValue.arrayUnion([applicantId]),
        'memberNicknames': FieldValue.arrayUnion([applicantNickname]),
        'memberCount': FieldValue.increment(1),
      });

      // 3. 신청자의 'users' 문서에서 growthIndex를 5점 증가
      final userRef = firestore.collection('users').doc(applicantId);
      batch.update(userRef, {'growthIndex': FieldValue.increment(5)});

      // 스터디 멤버가 꽉 찼는지 확인 (이 부분은 get()이 필요해서 batch와 분리)
      final studyDoc = await studyRef.get();
      if (studyDoc.exists) {
        final studyData = studyDoc.data()!;
        final maxMembers = studyData['maxMembers'];
        final newMemberCount = (studyData['memberCount'] ?? 0) + 1;

        if (newMemberCount >= maxMembers) {
          batch.update(studyRef, {'isRecruiting': false});
        }
      }
    }

    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신청을 $status 처리했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... 이하 코드 변경 없음 ...
    return Scaffold(
      appBar: AppBar(title: Text('$studyTitle 신청자 목록')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('applications').where('studyId', isEqualTo: studyId).where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text('대기중인 신청자가 없습니다.'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final applicantId = data['applicantId'];
              final applicantNickname = data['applicantNickname'] ?? '정보 없음';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Text(applicantNickname.isNotEmpty ? applicantNickname[0].toUpperCase() : '?')),
                  title: Text(applicantNickname),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          tooltip: '수락',
                          onPressed: () => _updateApplicationStatus(context, doc.id, 'accepted', applicantId, applicantNickname)
                      ),
                      IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          tooltip: '거절',
                          onPressed: () => _updateApplicationStatus(context, doc.id, 'rejected', applicantId, applicantNickname)
                      ),
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