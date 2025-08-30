import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // ### REFACTORED: 관심사를 체계적으로 보여주기 위해 Map 형태로 데이터 구조 변경 ###
  final Map<String, List<String>> interestCategories = {
    '취업・이직': ['면접 준비', '서류 준비'],
    '외국어': ['말하기 시험', '어학 시험, 회화'],
    '자격증': ['IT/SW', '국어/역사', '금융/회계', '디자인/영상', '무역/물류', '사무/QA', '엔지니어링 (기사)'],
    '기타' : []
  };
  List<String> _selectedInterests = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _signUp() async {
    final nickname = nicknameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (nickname.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 필드를 입력해주세요.')));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관심 분야를 1개 이상 선택해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'phone': phone,
          'displayName': nickname,
          'createdAt': Timestamp.now(),
          'interests': _selectedInterests,
          'growthIndex': 0,
          // ### ADDED: 포인트 시스템을 위해 마지막 로그인 시간 초기화 ###
          'lastLogin': Timestamp.fromDate(DateTime(1970)),
        });

        await _auth.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다! 로그인해주세요.')));
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = '회원가입에 실패했습니다.';
      if (e.code == 'weak-password') message = '비밀번호는 6자리 이상이어야 합니다.';
      else if (e.code == 'email-already-in-use') message = '이미 사용 중인 이메일입니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(controller: nicknameController, label: '닉네임'),
                  const SizedBox(height: 16),
                  _buildTextField(controller: emailController, label: '이메일 주소', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildTextField(controller: phoneController, label: '휴대폰 번호 (- 제외)', keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildTextField(controller: passwordController, label: '비밀번호', obscureText: true),
                  const SizedBox(height: 16),
                  _buildTextField(controller: confirmPasswordController, label: '비밀번호 확인', obscureText: true),
                  const SizedBox(height: 24),

                  Text('관심 분야를 선택해주세요', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // ### REFACTORED: 기존 Wrap 위젯을 체계적인 UI를 가진 새 위젯으로 교체 ###
                  _InterestSelector(
                    categories: interestCategories,
                    initialSelection: _selectedInterests,
                    onSelectionChanged: (selected) {
                      setState(() {
                        _selectedInterests = selected;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    child: const Text('회원가입 완료'),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, bool obscureText = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ### NEW: 관심 분야 선택을 위한 새로운 위젯 ###
class _InterestSelector extends StatefulWidget {
  final Map<String, List<String>> categories;
  final List<String> initialSelection;
  final Function(List<String>) onSelectionChanged;

  const _InterestSelector({
    required this.categories,
    required this.initialSelection,
    required this.onSelectionChanged,
  });

  @override
  State<_InterestSelector> createState() => _InterestSelectorState();
}

class _InterestSelectorState extends State<_InterestSelector> {
  late String _selectedMainCategory;
  late List<String> _currentSelectedInterests;

  @override
  void initState() {
    super.initState();
    _selectedMainCategory = widget.categories.keys.first;
    _currentSelectedInterests = List.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 왼쪽: 메인 카테고리 목록
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: ListView.builder(
                itemCount: widget.categories.keys.length,
                itemBuilder: (context, index) {
                  final category = widget.categories.keys.elementAt(index);
                  final isSelected = category == _selectedMainCategory;
                  return ListTile(
                    title: Text(
                      category,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.teal : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedMainCategory = category;
                      });
                    },
                    selected: isSelected,
                    selectedTileColor: Colors.teal.withOpacity(0.1),
                  );
                },
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // 오른쪽: 서브 카테고리 (FilterChip)
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: widget.categories[_selectedMainCategory]!.map((interest) {
                  final isSelected = _currentSelectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _currentSelectedInterests.add(interest);
                        } else {
                          _currentSelectedInterests.remove(interest);
                        }
                      });
                      widget.onSelectionChanged(_currentSelectedInterests);
                    },
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
