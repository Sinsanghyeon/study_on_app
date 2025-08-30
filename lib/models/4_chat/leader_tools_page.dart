import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaderToolsPage extends StatefulWidget {
  final String studyId;
  const LeaderToolsPage({super.key, required this.studyId});

  @override
  State<LeaderToolsPage> createState() => _LeaderToolsPageState();
}

class _LeaderToolsPageState extends State<LeaderToolsPage> {

  Future<Map<String, dynamic>> _fetchManagementData() async {
    final firestore = FirebaseFirestore.instance;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final studyDoc = await firestore.collection('studies').doc(widget.studyId).get();
    if (!studyDoc.exists) return {};
    final studyData = studyDoc.data()!;

    final memberUids = List<String>.from(studyData['members'] ?? []);
    final memberNicknames = List<String>.from(studyData['memberNicknames'] ?? []);
    final leaderId = studyData['leaderId'];

    final msgSnapshot = await firestore.collection('chats').doc(widget.studyId).collection('messages')
        .where('timestamp', isGreaterThan: sevenDaysAgo)
        .orderBy('timestamp', descending: true)
        .get();

    Map<String, _MemberStats> memberStats = {};
    for (var uid in memberUids) {
      memberStats[uid] = _MemberStats(messageCount: 0, lastSeen: null);
    }

    for (var doc in msgSnapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId'] as String;
      if (memberStats.containsKey(senderId)) {
        int currentCount = memberStats[senderId]!.messageCount;
        memberStats[senderId] = _MemberStats(
          messageCount: currentCount + 1,
          lastSeen: memberStats[senderId]!.lastSeen ?? (data['timestamp'] as Timestamp).toDate(),
        );
      }
    }

    return {
      'nicknames': Map.fromIterables(memberUids, memberNicknames),
      'leaderId': leaderId,
      'stats': memberStats,
    };
  }

  Future<void> _updateApplicationStatus(String docId, String status, String applicantId, String applicantNickname) async {
    final firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();

    batch.update(firestore.collection('applications').doc(docId), {'status': status});

    if (status == 'accepted') {
      final studyRef = firestore.collection('studies').doc(widget.studyId);
      final studyDoc = await studyRef.get();
      if (!studyDoc.exists) return;

      final studyData = studyDoc.data()!;
      final maxMembers = studyData['maxMembers'];
      final newMemberCount = (studyData['memberCount'] ?? 0) + 1;

      batch.update(studyRef, {
        'members': FieldValue.arrayUnion([applicantId]),
        'memberNicknames': FieldValue.arrayUnion([applicantNickname]),
        'memberCount': FieldValue.increment(1),
      });

      if (newMemberCount >= maxMembers) {
        batch.update(studyRef, {'isRecruiting': false});
      }
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신청을 $status 처리했습니다.')));
    }
  }

  Future<void> _transferLeadership(String newLeaderId, String newLeaderNickname) async {
    await FirebaseFirestore.instance.collection('studies').doc(widget.studyId).update({
      'leaderId': newLeaderId,
      'leaderNickname': newLeaderNickname,
    });
    if (mounted) {
      Navigator.pop(context);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$newLeaderNickname 님에게 스터디장을 위임했습니다.')));
    }
  }

  Future<void> _removeMember(String memberId, String memberNickname) async {
    if (memberId == FirebaseAuth.instance.currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('자기 자신을 제외할 수 없습니다.')));
      return;
    }

    WriteBatch batch = FirebaseFirestore.instance.batch();

    final studyRef = FirebaseFirestore.instance.collection('studies').doc(widget.studyId);
    batch.update(studyRef, {
      'members': FieldValue.arrayRemove([memberId]),
      'memberNicknames': FieldValue.arrayRemove([memberNickname]),
      'memberCount': FieldValue.increment(-1),
    });

    final userRef = FirebaseFirestore.instance.collection('users').doc(memberId);
    batch.update(userRef, {'growthIndex': FieldValue.increment(-50)});

    await batch.commit();

    if(mounted) {
      Navigator.pop(context);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $memberNickname 님을 스터디에서 제외하고, 50 포인트를 차감했습니다.')));
    }
  }

  void _startCheckIn() {
    final now = DateTime.now();
    final validUntil = now.add(const Duration(minutes: 10));

    WriteBatch batch = FirebaseFirestore.instance.batch();

    final checkInRef = FirebaseFirestore.instance.collection('studies').doc(widget.studyId).collection('check_ins').doc();
    batch.set(checkInRef, {
      'createdAt': Timestamp.now(),
      'validUntil': Timestamp.fromDate(validUntil),
      'attendees': [],
    });

    final chatMessageRef = FirebaseFirestore.instance.collection('chats').doc(widget.studyId).collection('messages').doc();
    batch.set(chatMessageRef, {
      'messageType': 'check_in_status',
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? 'system',
      'senderNickname': '시스템',
      'message': '출석체크가 시작되었습니다.',
      'timestamp': FieldValue.serverTimestamp(),
      'validUntil': Timestamp.fromDate(validUntil),
    });

    batch.commit().then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출석체크를 시작했습니다. 10분간 유효합니다.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스터디장 도구')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildRecruitmentSection(),
          const SizedBox(height: 16),
          _buildAttendanceSection(),
          const SizedBox(height: 16),
          _buildApplicationSection(),
          const SizedBox(height: 16),
          _buildMemberManagementSection(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRecruitmentSection() {
    return _buildSectionCard(
      title: '📢 스터디원 모집',
      subtitle: '새로운 멤버를 모집할지 결정합니다.',
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('studies').doc(widget.studyId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final isRecruiting = (snapshot.data!.data() as Map<String, dynamic>?)?['isRecruiting'] ?? false;
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('모집 활성화'),
            subtitle: Text(isRecruiting ? '현재 모집 중 (검색에 노출됨)' : '현재 모집 마감됨'),
            value: isRecruiting,
            onChanged: (val) {
              FirebaseFirestore.instance.collection('studies').doc(widget.studyId).update({'isRecruiting': val});
            },
          );
        },
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return _buildSectionCard(
      title: '🙋‍♂️ 출석 체크',
      subtitle: '채팅방에 10분간 유효한 출석체크를 시작합니다.',
      child: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('출석 체크 시작하기'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: _startCheckIn,
        ),
      ),
    );
  }

  Widget _buildApplicationSection() {
    return _buildSectionCard(
      title: '📩 가입 신청 관리',
      subtitle: '스터디 가입 신청을 수락하거나 거절합니다.',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('applications')
            .where('studyId', isEqualTo: widget.studyId)
            .where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('대기중인 신청자가 없습니다.'));

          return Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final applicantId = data['applicantId'];
              final applicantNickname = data['applicantNickname'] ?? '이름없음';
              return ListTile(
                leading: CircleAvatar(child: Text(applicantNickname.isNotEmpty ? applicantNickname[0] : '?')),
                title: Text(applicantNickname),
                subtitle: Text(data['applicantEmail'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.check, color: Colors.green), tooltip: '수락', onPressed: () => _updateApplicationStatus(doc.id, 'accepted', applicantId, applicantNickname)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.red), tooltip: '거절', onPressed: () => _updateApplicationStatus(doc.id, 'rejected', applicantId, applicantNickname)),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildMemberManagementSection() {
    return _buildSectionCard(
      title: '👥 멤버 관리',
      subtitle: '스터디 멤버를 관리하거나 스터디장을 위임합니다.',
      child: FutureBuilder<Map<String, dynamic>>(
        future: _fetchManagementData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const ListTile(title: Text('멤버 정보를 불러올 수 없습니다.'));

          final nicknames = snapshot.data!['nicknames'] as Map<String, String>;
          final leaderId = snapshot.data!['leaderId'] as String;
          final stats = snapshot.data!['stats'] as Map<String, _MemberStats>;

          return Column(
            children: nicknames.keys.map((uid) {
              final nickname = nicknames[uid]!;
              final memberStat = stats[uid]!;
              final isCurrentLeader = uid == leaderId;
              String subtitleText = memberStat.lastSeen != null
                  ? '최근 활동: ${DateFormat('yy/MM/dd').format(memberStat.lastSeen!)}'
                  : '최근 활동 없음';

              return ListTile(
                leading: CircleAvatar(child: Text(nickname.isNotEmpty ? nickname[0].toUpperCase() : '?')),
                title: Row(
                  children: [
                    Text(nickname),
                    if (isCurrentLeader) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.stars, color: Colors.amber, size: 16),
                    ]
                  ],
                ),
                subtitle: Text(subtitleText),
                trailing: isCurrentLeader ? null : IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.military_tech_outlined),
                            title: const Text('스터디장으로 지정'),
                            onTap: () => _transferLeadership(uid, nickname),
                          ),
                          ListTile(
                            leading: const Icon(Icons.exit_to_app, color: Colors.red),
                            title: const Text('스터디에서 제외하기', style: TextStyle(color: Colors.red)),
                            onTap: () => _removeMember(uid, nickname),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _MemberStats {
  final int messageCount;
  final DateTime? lastSeen;
  _MemberStats({required this.messageCount, this.lastSeen});
}

