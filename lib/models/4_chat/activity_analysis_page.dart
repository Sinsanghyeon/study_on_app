import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ### REFACTORED: 파일 이름과 클래스 이름을 ActivityAnalysisPage -> StudyDashboardPage로 변경 ###
class StudyDashboardPage extends StatefulWidget {
  final String studyId;
  const StudyDashboardPage({super.key, required this.studyId});

  @override
  State<StudyDashboardPage> createState() => _StudyDashboardPageState();
}

class _StudyDashboardPageState extends State<StudyDashboardPage> {
  // ### REFACTORED: 복잡한 데이터 구조를 더 명확한 클래스로 분리 ###
  Future<StudyDashboardData?> _fetchDashboardData() async {
    final firestore = FirebaseFirestore.instance;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final studyDoc = await firestore.collection('studies').doc(widget.studyId).get();
    if (!studyDoc.exists) return null;

    final studyData = studyDoc.data()!;
    final memberUids = List<String>.from(studyData['members'] ?? []);
    final memberNicknames = List<String>.from(studyData['memberNicknames'] ?? []);
    if (memberUids.isEmpty) return null;

    final Map<String, String> uidToNickname = { for(var i=0; i < memberUids.length; i++) memberUids[i] : (i < memberNicknames.length ? memberNicknames[i] : 'uid-$i') };

    final msgSnapshot = await firestore.collection('chats').doc(widget.studyId).collection('messages')
        .where('timestamp', isGreaterThan: sevenDaysAgo).get();

    final checkInsSnapshot = await firestore.collection('studies').doc(widget.studyId).collection('check_ins')
        .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo).get();

    final todosSnapshot = await firestore.collection('studies').doc(widget.studyId).collection('todos')
        .where('isDone', isEqualTo: true)
        .where('completedAt', isGreaterThan: sevenDaysAgo).get();

    Map<String, int> memberActivityScores = { for (var uid in memberUids) uid: 0 };
    Map<String, int> memberAttendance = { for (var uid in memberUids) uid: 0 };
    Map<String, int> dailyMessageCounts = {};
    int totalQaCount = 0;

    for (var doc in msgSnapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId'] as String?;
      if (senderId != null && memberActivityScores.containsKey(senderId)) {
        // 활동 점수 계산
        if (data['messageType'] == 'question') {
          memberActivityScores[senderId] = memberActivityScores[senderId]! + 3; // 질문 3점
          totalQaCount++;
        } else if (data['messageType'] == 'text') {
          memberActivityScores[senderId] = memberActivityScores[senderId]! + 1; // 일반 메시지 1점
        }
        if (data.containsKey('answers') && (data['answers'] as List).isNotEmpty) {
          totalQaCount += (data['answers'] as List).length;
        }

        // 일별 메시지 카운트
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(timestamp.toDate());
          dailyMessageCounts[dateKey] = (dailyMessageCounts[dateKey] ?? 0) + 1;
        }
      }
    }
    for (var doc in todosSnapshot.docs) {
      final completerId = doc.data()['completedById'] as String?;
      if (completerId != null && memberActivityScores.containsKey(completerId)) {
        memberActivityScores[completerId] = memberActivityScores[completerId]! + 5; // 할일 완료 5점
      }
    }

    for (var doc in checkInsSnapshot.docs) {
      final attendees = List.from(doc.data()['attendees'] ?? []);
      for (var attendee in attendees) {
        final uid = attendee['uid'] as String?;
        if (uid != null && memberAttendance.containsKey(uid)) {
          memberAttendance[uid] = memberAttendance[uid]! + 1;
        }
      }
    }

    // MVP 선정 (활동 점수 + 출석 점수)
    memberUids.forEach((uid) {
      memberActivityScores[uid] = memberActivityScores[uid]! + (memberAttendance[uid]! * 10); // 출석 10점
    });

    // MVP 로직 수정: 멤버가 한명이라도 있으면 MVP를 선정합니다.
    final mvpUid = memberActivityScores.isNotEmpty
        ? memberActivityScores.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;

    final mostActiveDay = dailyMessageCounts.entries.isEmpty ? null : dailyMessageCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return StudyDashboardData(
      totalQaCount: totalQaCount,
      totalCompletedTodos: todosSnapshot.docs.length,
      mostActiveDay: mostActiveDay,
      mvpNickname: mvpUid != null ? (uidToNickname[mvpUid] ?? '없음') : '없음',
      memberStats: memberUids.map((uid) {
        return MemberStats(
          nickname: uidToNickname[uid]!,
          activityScore: memberActivityScores[uid]!,
          attendanceCount: memberAttendance[uid]!,
        );
      }).toList()..sort((a, b) => b.activityScore.compareTo(a.activityScore)),
      totalCheckInDays: checkInsSnapshot.docs.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ### REFACTORED: 페이지 이름 변경 ###
        title: const Text('스터디 대시보드'),
        actions: [
          // ### NEW: 대시보드 설명 팝업 추가 ###
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('💡 대시보드 안내'),
                content: const Text(
                    '지난 7일간의 스터디 활동을 요약해서 보여줘요.\n\n'
                        '활동 점수는 채팅, 질문, 할 일 완료, 출석 등을 종합하여 계산되며, 누가 스터디에 가장 열정적으로 참여했는지 알 수 있는 지표입니다.'
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
              ),
            ),
          )
        ],
      ),
      body: FutureBuilder<StudyDashboardData?>(
        future: _fetchDashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('아직 분석할 데이터가 충분하지 않아요.\n스터디 활동을 시작해보세요!'));
          }
          final data = snapshot.data!;
          // ### REFACTORED: 전체 UI를 위젯 함수로 분리하여 가독성 개선 ###
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIntroCard(data),
                const SizedBox(height: 24),
                _buildActivityRanking(context, data),
              ],
            ),
          );
        },
      ),
    );
  }

  // ### NEW: 대시보드 상단 요약 카드 ###
  Widget _buildIntroCard(StudyDashboardData data) {
    String mostActiveDayText = "아직 활동이 없어요";
    if (data.mostActiveDay != null) {
      final date = DateTime.parse(data.mostActiveDay!);
      mostActiveDayText = "${DateFormat('M월 d일 EEEE', 'ko_KR').format(date)}에\n가장 활발했어요!";
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('지난 7일, 우리 스터디는...', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHighlightItem(Icons.star_rounded, Colors.amber, '이번 주 MVP', data.mvpNickname),
                _buildHighlightItem(Icons.calendar_today_rounded, Colors.blue, '최고 집중의 날', mostActiveDayText),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHighlightItem(Icons.question_answer_rounded, Colors.green, '질문/답변', '${data.totalQaCount} 개'),
                _buildHighlightItem(Icons.check_circle_rounded, Colors.purple, '완료한 할 일', '${data.totalCompletedTodos} 개'),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ### NEW: 상단 요약 카드의 개별 아이템 위젯 ###
  Widget _buildHighlightItem(IconData icon, Color color, String title, String value) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ### NEW: 멤버별 활동 순위 위젯 ###
  Widget _buildActivityRanking(BuildContext context, StudyDashboardData data) {
    final maxScore = data.memberStats.isEmpty ? 1 : data.memberStats.first.activityScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('주간 활동 순위 🏆', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.memberStats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final member = data.memberStats[index];
            final progress = maxScore == 0 ? 0.0 : member.activityScore / maxScore;
            String rankIcon = '';
            if (index == 0) rankIcon = '🥇';
            else if (index == 1) rankIcon = '🥈';
            else if (index == 2) rankIcon = '🥉';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('${index + 1} $rankIcon', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        CircleAvatar(child: Text(member.nickname.isNotEmpty ? member.nickname[0] : '?')),
                        const SizedBox(width: 12),
                        Expanded(child: Text(member.nickname, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text('${member.activityScore} 점', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade600, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade300),
                      ),
                    ),
                    if (data.totalCheckInDays > 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('출석: ${member.attendanceCount} / ${data.totalCheckInDays} 회', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ### NEW: 대시보드 데이터를 담기 위한 모델 클래스 ###
class StudyDashboardData {
  final int totalQaCount;
  final int totalCompletedTodos;
  final String? mostActiveDay;
  final String mvpNickname;
  final List<MemberStats> memberStats;
  final int totalCheckInDays;

  StudyDashboardData({
    required this.totalQaCount,
    required this.totalCompletedTodos,
    this.mostActiveDay,
    required this.mvpNickname,
    required this.memberStats,
    required this.totalCheckInDays,
  });
}

class MemberStats {
  final String nickname;
  final int activityScore;
  final int attendanceCount;

  MemberStats({
    required this.nickname,
    required this.activityScore,
    required this.attendanceCount,
  });
}

