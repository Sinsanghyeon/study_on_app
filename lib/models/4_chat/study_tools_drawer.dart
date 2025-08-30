import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StudyToolsDrawer extends StatefulWidget {
  final String studyId;
  const StudyToolsDrawer({super.key, required this.studyId});

  @override
  State<StudyToolsDrawer> createState() => _StudyToolsDrawerState();
}

class _StudyToolsDrawerState extends State<StudyToolsDrawer> {
  final _firestore = FirebaseFirestore.instance;
  // ### NEW: 현재 사용자 정보 가져오기 ###
  final _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }
  // ### NEW: 끝 ###

  void _showAddItemDialog({
    required String title,
    required String collectionName,
    required Map<String, dynamic> data,
  }) {
    final textController = TextEditingController();
    if (data.containsKey('date')) {
      showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      ).then((pickedDate) {
        if (pickedDate == null) return;
        data['date'] = Timestamp.fromDate(pickedDate);
        _showTextDialog(title: title, collectionName: collectionName, data: data, controller: textController);
      });
    } else {
      _showTextDialog(title: title, collectionName: collectionName, data: data, controller: textController);
    }
  }

  // ### MODIFIED: 링크 공유 시 포인트 지급 로직 추가 ###
  void _showTextDialog({
    required String title,
    required String collectionName,
    required Map<String, dynamic> data,
    required TextEditingController controller,
  }) {
    String label = data.containsKey('url') ? 'URL' : '내용';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty || _currentUser == null) return;
              String key = data.containsKey('url') ? 'url' : 'title';
              data[key] = controller.text.trim();

              final isLinkSharing = collectionName == 'links';

              // --- 포인트 시스템: 링크 공유 ---
              if (isLinkSharing) {
                data['creatorId'] = _currentUser!.uid; // 링크 생성자 ID 추가

                WriteBatch batch = _firestore.batch();

                final linkRef = _firestore.collection('studies').doc(widget.studyId).collection(collectionName).doc();
                batch.set(linkRef, data);

                final userRef = _firestore.collection('users').doc(_currentUser!.uid);
                batch.update(userRef, {'growthIndex': FieldValue.increment(10)});

                batch.commit().then((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔗 링크를 공유했습니다. +10 포인트를 얻었습니다!'))
                    );
                  }
                });
              } else {
                _firestore
                    .collection('studies')
                    .doc(widget.studyId)
                    .collection(collectionName)
                    .add(data);
              }
              // --- 포인트 시스템 끝 ---
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal.shade50),
            child: const Text('🧰 스터디 도구함', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          // ### NEW: 출석 체크 섹션 위젯 추가 ###
          _buildAttendanceSection(),
          const Divider(),
          // ### NEW: 끝 ###
          _buildSection<Map<String, dynamic>>(
            title: '✅ 할 일 목록 (To-do)',
            collectionName: 'todos',
            orderBy: 'createdAt',
            // ### MODIFIED: 할 일 완료 시 포인트 지급 로직 추가 ###
            itemBuilder: (doc) {
              final todo = doc.data();
              final bool isDone = todo['isDone'] ?? false;
              return CheckboxListTile(
                title: Text(todo['title']),
                value: isDone,
                onChanged: (val) {
                  if (_currentUser == null || val == null) return;
                  // --- 포인트 시스템: 할 일 완료 ---
                  if (val == true && isDone == false) {
                    // 처음으로 '완료'로 변경하는 경우
                    WriteBatch batch = _firestore.batch();

                    batch.update(doc.reference, {
                      'isDone': true,
                      'completedById': _currentUser!.uid,
                      'completedAt': FieldValue.serverTimestamp(),
                    });

                    final userRef = _firestore.collection('users').doc(_currentUser!.uid);
                    batch.update(userRef, {'growthIndex': FieldValue.increment(5)});

                    batch.commit().then((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ 할 일을 완료했습니다. +5 포인트를 얻었습니다!'))
                        );
                      }
                    });
                  } else {
                    doc.reference.update({'isDone': val});
                  }
                  // --- 포인트 시스템 끝 ---
                },
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
            onAdd: () => _showAddItemDialog(
              title: '할 일 추가',
              collectionName: 'todos',
              data: {'title': '', 'isDone': false, 'createdAt': FieldValue.serverTimestamp()},
            ),
          ),
          _buildSection<Map<String, dynamic>>(
            title: '🗓️ 주요 일정',
            collectionName: 'schedule',
            orderBy: 'date',
            itemBuilder: (doc) {
              final schedule = doc.data();
              final date = (schedule['date'] as Timestamp).toDate();
              return ListTile(
                leading: const Icon(Icons.event_note, color: Colors.teal),
                title: Text(schedule['title']),
                subtitle: Text(DateFormat('yyyy-MM-dd (E)').format(date)),
                onLongPress: () => doc.reference.delete(),
              );
            },
            onAdd: () => _showAddItemDialog(
              title: '일정 추가 (날짜 선택)',
              collectionName: 'schedule',
              data: {'title': '', 'date': null},
            ),
          ),
          _buildSection<Map<String, dynamic>>(
            title: '🔗 자료 링크',
            collectionName: 'links',
            orderBy: 'createdAt',
            itemBuilder: (doc) {
              final link = doc.data();
              return ListTile(
                leading: const Icon(Icons.link, color: Colors.teal),
                title: Text(link['title']),
                subtitle: Text(link['url'], maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  final uri = Uri.tryParse(link['url']);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                onLongPress: () => doc.reference.delete(),
              );
            },
            onAdd: () => _showAddItemDialog(
              title: '링크 추가',
              collectionName: 'links',
              data: {'title': '', 'url': '', 'createdAt': FieldValue.serverTimestamp()},
            ),
          ),
        ],
      ),
    );
  }

  // ### NEW: 출석 체크 위젯 및 로직 ###
  Widget _buildAttendanceSection() {
    if (_currentUser == null) return const SizedBox.shrink();

    final now = Timestamp.now();
    final query = _firestore
        .collection('studies')
        .doc(widget.studyId)
        .collection('check_ins')
        .where('validUntil', isGreaterThan: now)
        .orderBy('validUntil', descending: true)
        .limit(1);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.timer_off_outlined, color: Colors.grey),
            title: Text('진행중인 출석체크 없음'),
          );
        }

        final checkInDoc = snapshot.data!.docs.first;
        final data = checkInDoc.data() as Map<String, dynamic>;
        final attendees = List.from(data['attendees'] ?? []);
        final alreadyAttended = attendees.any((attendee) => attendee['uid'] == _currentUser!.uid);

        return ListTile(
          leading: Icon(
            alreadyAttended ? Icons.check_circle : Icons.pending_actions_outlined,
            color: alreadyAttended ? Colors.green : Colors.orange,
          ),
          title: Text(alreadyAttended ? '출석 완료' : '출석 체크 진행 중'),
          trailing: ElevatedButton(
            onPressed: alreadyAttended ? null : () async {
              // --- 포인트 시스템: 출석 체크 ---
              WriteBatch batch = _firestore.batch();

              batch.update(checkInDoc.reference, {
                'attendees': FieldValue.arrayUnion([
                  {'uid': _currentUser!.uid, 'timestamp': Timestamp.now()}
                ])
              });

              final userRef = _firestore.collection('users').doc(_currentUser!.uid);
              batch.update(userRef, {'growthIndex': FieldValue.increment(10)});

              await batch.commit();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🙋‍♂️ 출석체크 완료! +10 포인트를 얻었습니다.'))
                );
              }
              // --- 포인트 시스템 끝 ---
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: alreadyAttended ? Colors.grey : Colors.teal,
            ),
            child: Text(alreadyAttended ? '완료' : '출석하기'),
          ),
        );
      },
    );
  }

  Widget _buildSection<T>({
    required String title,
    required String collectionName,
    required String orderBy,
    required Widget Function(QueryDocumentSnapshot<T>) itemBuilder,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, color: Colors.teal)),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot<T>>(
          stream: _firestore
              .collection('studies')
              .doc(widget.studyId)
              .collection(collectionName)
              .orderBy(orderBy)
              .withConverter<T>(
            fromFirestore: (snapshot, _) => snapshot.data()! as T,
            toFirestore: (value, _) => value as Map<String, dynamic>,
          )
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('등록된 항목이 없습니다.', style: TextStyle(color: Colors.grey)));
            }
            return Column(
              children: snapshot.data!.docs.map(itemBuilder).toList(),
            );
          },
        ),
        const Divider(),
      ],
    );
  }
}
