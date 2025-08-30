import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
            .where('isRecruiting', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('참여중인 채팅방이 없습니다.\n스터디 모집이 완료되면 채팅방이 활성화됩니다.', textAlign: TextAlign.center));

          return ListView(
            padding: const EdgeInsets.all(8),
            children: snapshot.data!.docs.map((doc) {
              final studyData = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.chat, color: Colors.teal),
                  title: Text(studyData['title']),
                  subtitle: const Text("채팅방으로 이동하기"),
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