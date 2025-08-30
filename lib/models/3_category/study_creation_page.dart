import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'category_data.dart';

class StudyCreationPage extends StatefulWidget {
  const StudyCreationPage({super.key});

  @override
  State<StudyCreationPage> createState() => _StudyCreationPageState();
}

class _StudyCreationPageState extends State<StudyCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  // [추가] 오프라인 스터디 장소 입력을 위한 컨트롤러
  final _locationController = TextEditingController();

  String? _selectedCategory;
  int _maxMembers = 2;
  DateTime? _deadline;
  bool _isLoading = false;
  // [추가] 스터디 진행 방식을 저장할 변수 (기본값 '온라인')
  String _studyType = '온라인';

  // [추가] 컨트롤러 메모리 해제를 위한 dispose 메서드
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createStudy() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모집 마감일을 선택해주세요.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final userNickname = userDoc.data()?['displayName'] ?? '리더';

      await FirebaseFirestore.instance.collection('studies').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        // [추가] 진행 방식과 장소 정보를 Firestore에 저장
        'type': _studyType,
        'location': _studyType == '오프라인' ? _locationController.text.trim() : null,
        'leaderId': currentUser.uid,
        'leaderNickname': userNickname,
        'members': [currentUser.uid],
        'memberNicknames': [userNickname],
        'memberCount': 1,
        'maxMembers': _maxMembers,
        'deadline': Timestamp.fromDate(_deadline!),
        'createdAt': FieldValue.serverTimestamp(),
        'isRecruiting': true,
        'lastMessage': '스터디가 개설되었습니다!',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 스터디가 성공적으로 개설되었습니다!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('스터디 개설에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && pickedDate != _deadline) {
      setState(() {
        _deadline = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스터디 개설')),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildSectionTitle('스터디 기본 정보'),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '스터디 제목'),
                  validator: (value) => value!.trim().isEmpty ? '제목을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  hint: const Text('카테고리 선택'),
                  items: studyCategories.values
                      .expand((subList) => subList)
                      .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                  validator: (value) => value == null ? '카테고리를 선택해주세요.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '스터디 설명', alignLabelWithHint: true),
                  maxLines: 5,
                  validator: (value) => value!.trim().isEmpty ? '설명을 입력해주세요.' : null,
                ),
                const SizedBox(height: 24),

                // [추가] 진행 방식 선택 UI
                _buildSectionTitle('진행 방식'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: '온라인',
                      groupValue: _studyType,
                      onChanged: (value) => setState(() => _studyType = value!),
                    ),
                    const Text('온라인'),
                    const SizedBox(width: 24),
                    Radio<String>(
                      value: '오프라인',
                      groupValue: _studyType,
                      onChanged: (value) => setState(() => _studyType = value!),
                    ),
                    const Text('오프라인'),
                  ],
                ),
                // [추가] 오프라인 선택 시에만 장소 입력 필드 표시
                if (_studyType == '오프라인')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: '스터디 장소 (예: 서울시 강남구)',
                        hintText: '주요 활동 지역을 입력해주세요.',
                      ),
                      validator: (value) {
                        if (_studyType == '오프라인' && (value == null || value.trim().isEmpty)) {
                          return '오프라인 스터디는 장소를 반드시 입력해야 합니다.';
                        }
                        return null;
                      },
                    ),
                  ),
                const SizedBox(height: 24),

                _buildSectionTitle('모집 정보'),
                Row(
                  children: [
                    const Text('최대 인원: '),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _maxMembers,
                      items: List.generate(9, (i) => i + 2) // 2명부터 10명까지
                          .map((num) => DropdownMenuItem(value: num, child: Text('$num 명')))
                          .toList(),
                      onChanged: (value) => setState(() => _maxMembers = value!),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('모집 마감일'),
                  subtitle: Text(
                    _deadline == null ? '날짜를 선택해주세요' : DateFormat('yyyy년 MM월 dd일').format(_deadline!),
                    style: TextStyle(
                      color: _deadline == null ? Colors.grey : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDeadline(context),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createStudy,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('스터디 개설하기', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
      ),
    );
  }
}