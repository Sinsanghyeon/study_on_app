import 'package:flutter/material.dart';
import '../screens/study_detail_page.dart';

class StudyCard extends StatelessWidget {
  final String studyId;
  final Map<String, dynamic> study;
  const StudyCard({super.key, required this.studyId, required this.study});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(study['title'] ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(study['desc'] ?? '설명 없음'),
            const SizedBox(height: 8),
            Text("모집현황: ${study['memberCount'] ?? 1}/${study['maxMembers'] ?? '?'}", style: const TextStyle(color: Colors.teal)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyDetailPage(studyId: studyId, studyData: study))),
      ),
    );
  }
}