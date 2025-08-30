import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'study_detail_page.dart';

class StudyCard extends StatelessWidget {
  final String studyId;
  final Map<String, dynamic> studyData;

  const StudyCard({super.key, required this.studyId, required this.studyData});

  @override
  Widget build(BuildContext context) {
    final title = studyData['title'] ?? '제목 없음';
    final category = studyData['category'] ?? '미지정';
    final leaderNickname = studyData['leaderNickname'] ?? '리더 없음';
    final memberCount = studyData['memberCount'] ?? 0;
    final maxMembers = studyData['maxMembers'] ?? 1;
    final deadline = (studyData['deadline'] as Timestamp?)?.toDate();
    final type = studyData['type'] ?? '온라인';
    final location = studyData['location'] ?? '장소 미정';

    String dDay = '마감';
    Color dDayColor = Colors.grey;
    if (deadline != null) {
      final difference = deadline.difference(DateTime.now()).inDays;
      if (difference >= 0) {
        dDay = 'D-${difference + 1}';
        dDayColor = difference < 3 ? Colors.red.shade700 : Colors.green.shade700;
      }
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudyDetailPage(studyId: studyId, studyData: studyData),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dDayColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(dDay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Chip(
                        label: Text(category, style: TextStyle(color: Colors.teal.shade800, fontSize: 12)),
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.person_outline, leaderNickname),
              const SizedBox(height: 6),
              _buildInfoRow(
                type == '온라인' ? Icons.laptop_mac_outlined : Icons.location_on_outlined,
                type == '온라인' ? '온라인' : location,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('참여 현황', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('$memberCount / $maxMembers 명', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: maxMembers > 0 ? memberCount / maxMembers : 0,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade300),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
