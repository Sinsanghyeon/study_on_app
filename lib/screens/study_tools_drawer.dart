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

  // 할 일, 일정, 링크 추가를 위한 공용 다이얼로그
  void _showAddItemDialog({
    required String title,
    required String collectionName,
    required Map<String, dynamic> data,
  }) {
    final textController = TextEditingController();
    // 일정 추가 시, 날짜 선택 로직
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
      // 할 일, 링크 추가 시
      _showTextDialog(title: title, collectionName: collectionName, data: data, controller: textController);
    }
  }

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
              if (controller.text.trim().isEmpty) return;
              String key = data.containsKey('url') ? 'url' : 'title';
              data[key] = controller.text.trim();

              _firestore
                  .collection('studies')
                  .doc(widget.studyId)
                  .collection(collectionName)
                  .add(data);
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
          // 1. 할 일 목록 섹션
          _buildSection<Map<String, dynamic>>(
            title: '✅ 할 일 목록 (To-do)',
            collectionName: 'todos',
            orderBy: 'createdAt',
            itemBuilder: (doc) {
              final todo = doc.data();
              return CheckboxListTile(
                title: Text(todo['title']),
                value: todo['isDone'],
                onChanged: (val) => doc.reference.update({'isDone': val}),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
            onAdd: () => _showAddItemDialog(
              title: '할 일 추가',
              collectionName: 'todos',
              data: {'title': '', 'isDone': false, 'createdAt': FieldValue.serverTimestamp()},
            ),
          ),
          // 2. 주요 일정 섹션
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
          // 3. 자료 링크 섹션
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