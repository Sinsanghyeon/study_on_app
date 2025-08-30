import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicantListPage extends StatelessWidget {
  final String studyId;
  final String studyTitle;
  const ApplicantListPage({super.key, required this.studyId, required this.studyTitle});

  Future<void> _updateApplicationStatus(BuildContext context, String docId, String status, String applicantId, String applicantNickname) async {
    final firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();

    batch.update(firestore.collection('applications').doc(docId), {'status': status});

    if (status == 'accepted') {
      final studyRef = firestore.collection('studies').doc(studyId);
      batch.update(studyRef, {
        'members': FieldValue.arrayUnion([applicantId]),
        'memberNicknames': FieldValue.arrayUnion([applicantNickname]),
        'memberCount': FieldValue.increment(1),
      });

      final userRef = firestore.collection('users').doc(applicantId);
      batch.update(userRef, {'growthIndex': FieldValue.increment(5)});

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
