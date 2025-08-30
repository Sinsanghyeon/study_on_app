import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geocoding/geocoding.dart';

class StudyDetailPage extends StatefulWidget {
  final String studyId;
  final Map<String, dynamic> studyData;
  const StudyDetailPage({super.key, required this.studyId, required this.studyData});

  @override
  State<StudyDetailPage> createState() => _StudyDetailPageState();
}

class _StudyDetailPageState extends State<StudyDetailPage> {
  NaverMapController? _mapController;
  final Set<NMarker> _markers = {};
  NLatLng? _studyLocation;

  @override
  void initState() {
    super.initState();
    // [수정] studyData에 'type' 필드가 '오프라인'일 때만 지도 데이터 로드
    if (widget.studyData['type'] == '오프라인') {
      _loadMapData();
    }
  }

  Future<void> _loadMapData() async {
    String locationString = widget.studyData['location'] ?? '';
    if (locationString.isEmpty) return;

    try {
      // geocoding을 사용하여 주소 -> 좌표 변환
      List<Location> locations = await locationFromAddress(locationString);
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _studyLocation = NLatLng(location.latitude, location.longitude);
          final marker = NMarker(
            id: widget.studyId,
            position: _studyLocation!,
            caption: NOverlayCaption(text: widget.studyData['title']),
          );
          _markers.add(marker);
        });
      }
    } catch (e) {
      print("좌표 변환 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('스터디 장소의 좌표를 찾을 수 없습니다.'))
        );
      }
    }
  }

  void _applyForStudy(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (widget.studyData['members'] != null && (widget.studyData['members'] as List).contains(currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이미 참여중인 스터디입니다.")));
      return;
    }

    final existingApplication = await FirebaseFirestore.instance
        .collection('applications')
        .where('studyId', isEqualTo: widget.studyId)
        .where('applicantId', isEqualTo: currentUser.uid)
        .limit(1).get();

    if (existingApplication.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이미 신청한 스터디입니다.")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스터디 신청'),
        content: const Text('이 스터디에 정말 신청하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                final applicantNickname = userDoc.data()?['displayName'] as String? ?? '이름없음';

                await FirebaseFirestore.instance.collection('applications').add({
                  'studyId': widget.studyId,
                  'studyTitle': widget.studyData['title'],
                  'applicantId': currentUser.uid,
                  'applicantNickname': applicantNickname,
                  'applicantEmail': currentUser.email,
                  'status': 'pending',
                  'appliedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (completionCtx) => AlertDialog(
                      title: const Text('신청 완료'),
                      content: const Text('스터디 신청이 완료되었습니다.'),
                      actions: [TextButton(onPressed: () {Navigator.pop(completionCtx);Navigator.pop(context);}, child: const Text('확인'))],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오류가 발생했습니다: $e")));
                }
              }
            },
            child: const Text('신청'),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightInfo(BuildContext context, {required IconData icon, required String title, required String content}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.teal, size: 26),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(content, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.studyData['title'] ?? '제목 없음';
    // [수정] description 필드명을 desc에서 description으로 변경 (생성 페이지와 통일)
    final String description = widget.studyData['description'] ?? '소개글이 없습니다.';
    final String category = widget.studyData['category'] ?? '';
    final String leaderNickname = widget.studyData['leaderNickname'] ?? '정보 없음';
    final String leaderId = widget.studyData['leaderId'] ?? '';
    final int memberCount = widget.studyData['memberCount'] ?? 1;
    final int maxMembers = widget.studyData['maxMembers'] ?? 0;
    final bool isRecruiting = widget.studyData['isRecruiting'] ?? true;
    // [수정] 진행 방식과 위치 정보를 변수로 선언
    final String studyType = widget.studyData['type'] ?? '온라인';
    final String location = studyType == '오프라인' ? '${widget.studyData['location'] ?? '장소 미정'}' : '온라인';

    String deadlineText = '상시 모집';
    if (isRecruiting && widget.studyData['deadline'] != null && widget.studyData['deadline'] is Timestamp) {
      final deadline = (widget.studyData['deadline'] as Timestamp).toDate();
      final now = DateTime.now();
      final difference = deadline.difference(DateTime(now.year, now.month, now.day)).inDays;

      if (difference == 0) {
        deadlineText = '오늘 마감!';
      } else if (difference > 0) {
        deadlineText = 'D-$difference';
      } else {
        deadlineText = '모집 마감';
      }
    } else if (!isRecruiting) {
      deadlineText = '모집 완료';
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isLeader = currentUser?.uid == leaderId;
    final bool isMember = (widget.studyData['members'] as List?)?.contains(currentUser?.uid) ?? false;
    final bool canApply = !isLeader && !isMember && isRecruiting;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: Text(title),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_border)),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              if (category.isNotEmpty) ...[
                Chip(
                  label: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  backgroundColor: Colors.teal.shade50,
                ),
                const SizedBox(height: 12),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.3)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text(leaderNickname.isNotEmpty ? leaderNickname[0].toUpperCase() : '😎', style: const TextStyle(color: Colors.grey)),
                ),
                title: Text(leaderNickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("스터디장"),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isRecruiting ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: isRecruiting ? Colors.teal : Colors.red.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRecruiting ? "현재 모집중입니다." : "모집이 마감되었습니다.",
                    style: TextStyle(color: isRecruiting ? Colors.teal.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold),
                  )
                ],
              ),
              const Divider(height: 32),
              Card(
                elevation: 0,
                color: Colors.blue.shade50.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHighlightInfo(context, icon: Icons.people_alt_outlined, title: '모집 현황', content: '$memberCount/$maxMembers 명'),
                      // [수정] 진행 방식과 위치 정보를 표시하도록 수정
                      _buildHighlightInfo(context, icon: studyType == '온라인' ? Icons.laptop_mac_outlined : Icons.location_on_outlined, title: '진행 방식', content: location),
                      _buildHighlightInfo(context, icon: Icons.event_available_outlined, title: '모집 마감', content: deadlineText),
                    ],
                  ),
                ),
              ),
              // [수정] 오프라인 스터디이고, 지도 좌표가 성공적으로 로드되었을 때만 지도를 표시
              if (studyType == '오프라인' && _studyLocation != null) ...[
                const SizedBox(height: 32),
                Text('📍 스터디 장소', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: NaverMap(
                      options: NaverMapViewOptions(
                        initialCameraPosition: NCameraPosition(
                          target: _studyLocation!,
                          zoom: 15,
                        ),
                      ),
                      onMapReady: (controller) {
                        _mapController = controller;
                        _mapController?.addOverlayAll(_markers);
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text('📖 스터디 소개', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7, color: Colors.black87)),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 8),
        child: ElevatedButton(
          onPressed: canApply ? () => _applyForStudy(context) : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey.shade400,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
          ),
          child: Text(isLeader ? "내가 개설한 스터디" : (isMember ? "참여중인 스터디" : "스터디 신청하기")),
        ),
      ),
    );
  }
}