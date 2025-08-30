import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// REFACTORED: 같은 폴더 내의 파일 경로
import 'chatting_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다.'));

    return Scaffold(
      appBar: AppBar(title: const Text('채팅 목록')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('studies')
            .where('members', arrayContains: currentUser.uid)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('채팅 목록을 불러오는 중 오류가 발생했습니다.'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('참여중인 채팅방이 없습니다.\n스터디 모집이 완료되면 채팅방이 활성화됩니다.', textAlign: TextAlign.center));

          return ListView(
            padding: const EdgeInsets.all(8),
            children: snapshot.data!.docs.map((doc) {
              final studyData = doc.data() as Map<String, dynamic>;
              final timestamp = studyData['lastMessageTimestamp'] as Timestamp?;
              String lastTime = '';
              if (timestamp != null) {
                lastTime = DateFormat('yy/MM/dd HH:mm').format(timestamp.toDate());
              }

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.chat, color: Colors.teal),
                  title: Text(studyData['title']),
                  subtitle: Text(studyData['lastMessage'] ?? "채팅방으로 이동하기",  maxLines: 1, overflow: TextOverflow.ellipsis,),
                  trailing: Text(lastTime, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChattingPage(studyId: doc.id, studyTitle: studyData['title']))),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}