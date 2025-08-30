import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'study_tools_drawer.dart';

// ===================================================================
// --- 1. 채팅 목록 페이지 ---
// ===================================================================
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Scaffold(appBar: null, body: Center(child: Text('로그인이 필요합니다.')));

    return Scaffold(
      appBar: AppBar(title: const Text('채팅')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('studies')
            .where('members', arrayContains: currentUser.uid)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('채팅 목록을 불러오는 중 오류가 발생했습니다.'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('참여중인 채팅방이 없습니다.'));

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final studyData = doc.data() as Map<String, dynamic>;
              final timestamp = studyData['lastMessageTimestamp'] as Timestamp?;
              String lastTime = '';
              if (timestamp != null) {
                lastTime = DateFormat('yy/MM/dd HH:mm').format(timestamp.toDate());
              }

              return ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.shade50,
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.teal),
                ),
                title: Text(studyData['title'] ?? '스터디', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  studyData['lastMessage'] ?? '아직 메시지가 없습니다.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(lastTime, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChattingPage(studyId: doc.id, studyTitle: studyData['title']))),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}


// ===================================================================
// --- 2. 채팅방 페이지 ---
// ===================================================================
class ChattingPage extends StatefulWidget {
  final String studyId;
  final String studyTitle;
  const ChattingPage({super.key, required this.studyId, required this.studyTitle});

  @override
  State<ChattingPage> createState() => _ChattingPageState();
}

class _ChattingPageState extends State<ChattingPage> {
  final _messageController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String _leaderId = '';
  String? _currentUserNickname;

  Map<String, dynamic>? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudyAndUserData();
  }

  Future<void> _fetchStudyAndUserData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final studyDoc = await _firestore.collection('studies').doc(widget.studyId).get();
    if (studyDoc.exists && mounted) {
      setState(() {
        _leaderId = studyDoc.data()?['leaderId'] ?? '';
      });
    }

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if(userDoc.exists && mounted) {
      setState(() {
        _currentUserNickname = userDoc.data()?['displayName'] as String?;
      });
    }
  }

  void _sendMessage() {
    final currentUser = _auth.currentUser;
    if (_messageController.text.trim().isEmpty || currentUser == null || _currentUserNickname == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    FocusScope.of(context).unfocus();

    WriteBatch batch = _firestore.batch();
    DocumentReference messageRef = _firestore.collection('chats').doc(widget.studyId).collection('messages').doc();

    final messageData = {
      'messageType': 'text',
      'senderId': currentUser.uid,
      'senderNickname': _currentUserNickname,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'replyTo': _replyingToMessage,
    };

    batch.set(messageRef, messageData);

    DocumentReference studyRef = _firestore.collection('studies').doc(widget.studyId);
    batch.update(studyRef, {
      'lastMessage': _replyingToMessage != null ? '↪ 답장: $messageText' : messageText,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });

    batch.commit();

    setState(() {
      _replyingToMessage = null;
    });
  }

  void _sendQuestionMessage(String questionText) {
    final currentUser = _auth.currentUser;
    if (questionText.trim().isEmpty || currentUser == null || _currentUserNickname == null) return;

    WriteBatch batch = _firestore.batch();
    DocumentReference messageRef = _firestore.collection('chats').doc(widget.studyId).collection('messages').doc();
    batch.set(messageRef, {
      'messageType': 'question',
      'senderId': currentUser.uid,
      'senderNickname': _currentUserNickname,
      'message': questionText.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isResolved': false,
      'answers': [],
      'acceptedAnswer': null,
    });

    DocumentReference studyRef = _firestore.collection('studies').doc(widget.studyId);
    batch.update(studyRef, {
      'lastMessage': '❓ 질문: ${questionText.trim()}',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });

    batch.commit();
  }

  void _sendPollMessage(String question, List<String> options) {
    final currentUser = _auth.currentUser;
    if (question.trim().isEmpty || options.isEmpty || currentUser == null || _currentUserNickname == null) return;

    final optionsMap = { for (var option in options) option : [] };

    _firestore.collection('chats').doc(widget.studyId).collection('messages').add({
      'messageType': 'poll',
      'senderId': currentUser.uid,
      'senderNickname': _currentUserNickname,
      'question': question,
      'options': optionsMap,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _firestore.collection('studies').doc(widget.studyId).update({
      'lastMessage': '📊 투표: $question',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addAnswer(String messageId, String answerText) async {
    final currentUser = _auth.currentUser;
    if(currentUser == null || _currentUserNickname == null) return;

    final answer = {
      'id': const Uuid().v4(),
      'text': answerText,
      'authorId': currentUser.uid,
      'authorNickname': _currentUserNickname,
      'timestamp': Timestamp.now(),
    };

    await _firestore
        .collection('chats').doc(widget.studyId).collection('messages').doc(messageId)
        .update({'answers': FieldValue.arrayUnion([answer])});
  }

  Future<void> _acceptAnswer(String messageId, Map<String, dynamic> answer) async {
    await _firestore
        .collection('chats').doc(widget.studyId).collection('messages').doc(messageId)
        .update({
      'isResolved': true,
      'acceptedAnswer': answer,
    });
  }

  void _showMessageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blue),
              title: const Text('질문 등록하기'),
              onTap: () {
                Navigator.pop(ctx);
                _showQuestionDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined, color: Colors.orange),
              title: const Text('투표 만들기'),
              onTap: () {
                Navigator.pop(ctx);
                _showPollDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuestionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('질문 등록'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '질문 내용을 입력하세요...'),
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _sendQuestionMessage(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  void _showPollDialog() {
    final questionController = TextEditingController();
    List<TextEditingController> optionControllers = [TextEditingController(), TextEditingController()];

    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('투표 만들기'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: questionController, decoration: const InputDecoration(labelText: '질문')),
                      const SizedBox(height: 16),
                      ...List.generate(optionControllers.length, (index) {
                        return TextField(
                          controller: optionControllers[index],
                          decoration: InputDecoration(labelText: '선택지 ${index + 1}'),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('선택지 추가'),
                        onPressed: () {
                          setState(() => optionControllers.add(TextEditingController()));
                        },
                      )
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                  ElevatedButton(
                    onPressed: () {
                      final question = questionController.text.trim();
                      final options = optionControllers
                          .map((c) => c.text.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();
                      if (question.isNotEmpty && options.length >= 2) {
                        _sendPollMessage(question, options);
                        Navigator.pop(ctx);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('질문과 2개 이상의 선택지를 입력해주세요.')),
                        );
                      }
                    },
                    child: const Text('만들기'),
                  ),
                ],
              );
            },
          );
        });
  }

  void _setReplyingTo(String messageId, String sender, String message) {
    setState(() {
      _replyingToMessage = {
        'messageId': messageId,
        'senderNickname': sender,
        'message': message,
      };
    });
  }

  // [TEST] 테스트용 멤버와 대화 데이터를 생성하는 임시 함수입니다.
  Future<void> _addDummyMembersForTesting() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _currentUserNickname == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인 정보가 필요합니다.')));
      return;
    }

    final studyRef = _firestore.collection('studies').doc(widget.studyId);
    final chatRef = _firestore.collection('chats').doc(widget.studyId);

    final dummyMembers = [
      {'uid': 'dummy_uid_1', 'nickname': '김철수', 'email': 'chulsoo@test.com'},
      {'uid': 'dummy_uid_2', 'nickname': '이영희', 'email': 'younghee@test.com'},
      {'uid': 'dummy_uid_3', 'nickname': '박지성', 'email': 'jisung@test.com'},
    ];

    await studyRef.update({
      'members': FieldValue.arrayUnion([currentUser.uid, ...dummyMembers.map((m) => m['uid']!)]),
      'memberNicknames': FieldValue.arrayUnion([_currentUserNickname, ...dummyMembers.map((m) => m['nickname']!)]),
      'memberEmails': FieldValue.arrayUnion([currentUser.email, ...dummyMembers.map((m) => m['email']!)]),
    });

    final messages = [
      {'sender': dummyMembers[0], 'text': '안녕하세요! 스터디 참여합니다.'},
      {'sender': dummyMembers[1], 'text': '반갑습니다. 저도 오늘부터 시작이에요.'},
      {'sender': {'uid': currentUser.uid, 'nickname': _currentUserNickname}, 'text': '두 분 모두 환영합니다!'},
      {'sender': dummyMembers[2], 'text': '늦었네요. 잘 부탁드립니다.'},
      {'sender': dummyMembers[0], 'text': '오늘 스터디 범위가 어디까지였죠?'},
    ];

    WriteBatch batch = _firestore.batch();
    for(int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final sender = msg['sender'] as Map<String, dynamic>;
      final messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, {
        'messageType': 'text',
        'senderId': sender['uid'],
        'senderNickname': sender['nickname'],
        'message': msg['text'],
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2, hours: i))),
      });
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🐞 테스트용 멤버 3명과 대화 기록이 추가되었습니다.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = _auth.currentUser?.uid == _leaderId;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(widget.studyTitle),
        actions: [
          // [TEST] 테스트용 멤버 추가 버튼. 배포 전에는 이 IconButton을 삭제하세요.
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: "테스트용 멤버 추가하기",
            onPressed: _addDummyMembersForTesting,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: "스터디 활동 분석",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityAnalysisPage(studyId: widget.studyId))),
          ),
          if (isLeader)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: "스터디 관리",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderToolsPage(studyId: widget.studyId))),
            ),
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.construction_outlined),
                tooltip: "스터디 도구함",
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              );
            },
          ),
        ],
      ),
      endDrawer: StudyToolsDrawer(studyId: widget.studyId),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('chats').doc(widget.studyId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("아직 메시지가 없습니다."));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final currentTimestamp = data['timestamp'] as Timestamp?;
                    final prevDoc = (index + 1 < snapshot.data!.docs.length) ? snapshot.data!.docs[index + 1] : null;
                    final prevTimestamp = (prevDoc?.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?;

                    final Widget messageWidget;

                    final messageType = data['messageType'] as String?;

                    switch(messageType) {
                      case 'question':
                        messageWidget = _QuestionMessage(
                          messageId: doc.id,
                          data: data,
                          onAddAnswer: _addAnswer,
                          onAcceptAnswer: _acceptAnswer,
                        );
                        break;
                      case 'check_in_status':
                        messageWidget = _CheckInStatusMessage(validUntil: (data['validUntil'] as Timestamp).toDate());
                        break;
                      case 'poll':
                        messageWidget = _PollMessage(key: ValueKey(widget.studyId), messageId: doc.id, data: data);
                        break;
                      default:
                        messageWidget = _TextMessage(
                          messageId: doc.id,
                          data: data,
                          onReply: _setReplyingTo,
                        );
                    }

                    if (prevTimestamp == null || currentTimestamp == null || currentTimestamp.toDate().day != prevTimestamp.toDate().day) {
                      return Column(
                        children: [
                          _DateDivider(timestamp: currentTimestamp),
                          messageWidget,
                        ],
                      );
                    }
                    return messageWidget;
                  },
                );
              },
            ),
          ),
          Material(
            elevation: 5.0,
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.reply, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_replyingToMessage!['senderNickname']}에게 답장', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(
                                    _replyingToMessage!['message'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _replyingToMessage = null),
                            )
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                          onPressed: _showMessageOptions,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration.collapsed(hintText: "메시지를 입력하세요"),
                            onSubmitted: (value) => _sendMessage(),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.send, color: Colors.teal), onPressed: _sendMessage),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// --- 메시지 위젯들 ---
// ===================================================================

class _TextMessage extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final void Function(String messageId, String sender, String message) onReply;

  const _TextMessage({required this.messageId, required this.data, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final bool isMe = data['senderId'] == currentUser.uid;
    final senderNickname = data['senderNickname'] as String? ?? '이름없음';
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('답장하기'),
                onTap: () {
                  onReply(messageId, senderNickname, data['message']);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 48.0, bottom: 2.0),
                child: Text(senderNickname, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  CircleAvatar(
                    radius: 16,
                    child: Text(senderNickname.isNotEmpty ? senderNickname[0].toUpperCase() : '?'),
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                        color: isMe ? Colors.teal : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(1, 1))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if(replyTo != null)
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(width: 2, color: isMe ? Colors.teal.shade200 : Colors.grey.shade300),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(replyTo['senderNickname'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMe? Colors.white70 : Colors.black54)),
                                      Text(replyTo['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isMe? Colors.white70 : Colors.black54)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if(replyTo != null) const SizedBox(height: 8),
                        Text(data['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PollMessage extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> data;
  const _PollMessage({super.key, required this.messageId, required this.data});

  @override
  State<_PollMessage> createState() => __PollMessageState();
}

class __PollMessageState extends State<_PollMessage> {

  Future<void> _vote(String option) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final studyId = context.findAncestorWidgetOfExactType<ChattingPage>()!.studyId;
    final docRef = FirebaseFirestore.instance.collection('chats').doc(studyId).collection('messages').doc(widget.messageId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if(!snapshot.exists) throw Exception("Message does not exist!");

      final pollData = snapshot.data()!['options'] as Map<String, dynamic>;
      pollData.forEach((key, value) {
        (value as List).remove(currentUser.uid);
      });
      (pollData[option] as List).add(currentUser.uid);

      transaction.update(docRef, {'options': pollData});
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.data['question'] as String? ?? '';
    final options = widget.data['options'] as Map<String, dynamic>? ?? {};
    final senderNickname = widget.data['senderNickname'] as String? ?? '이름없음';
    final currentUser = FirebaseAuth.instance.currentUser;

    int totalVotes = 0;
    String? myVote;
    options.forEach((key, value) {
      final voters = value as List;
      totalVotes += voters.length;
      if(currentUser != null && voters.contains(currentUser.uid)) {
        myVote = key;
      }
    });

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text('투표', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              const Spacer(),
              Text('작성자: $senderNickname', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Divider(height: 16),
          Text(question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...options.entries.map((entry) {
            final optionText = entry.key;
            final voters = entry.value as List;
            final voteCount = voters.length;
            final percentage = totalVotes == 0 ? 0.0 : (voteCount / totalVotes);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: InkWell(
                onTap: () => _vote(optionText),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(myVote == optionText ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(optionText)),
                        Text('$voteCount표 (${(percentage * 100).toStringAsFixed(0)}%)', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      color: Colors.teal.shade200,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final Timestamp? timestamp;
  const _DateDivider({this.timestamp});

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final date = timestamp!.toDate();
    String text;

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      text = '오늘';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      text = '어제';
    } else {
      text = DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(date);
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _QuestionMessage extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final Function(String, String) onAddAnswer;
  final Function(String, Map<String, dynamic>) onAcceptAnswer;

  const _QuestionMessage({
    required this.messageId,
    required this.data,
    required this.onAddAnswer,
    required this.onAcceptAnswer,
  });

  void _showAnswerDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('답변하기'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '답변을 입력하세요...'),
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAddAnswer(messageId, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  void _showAllAnswers(BuildContext context, List<dynamic> answers, String questionAuthorId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: answers.length,
              itemBuilder: (context, index){
                final answer = answers[index] as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    title: Text(answer['text']),
                    subtitle: Text('답변자: ${answer['authorNickname']}'),
                    trailing: (currentUser?.uid == questionAuthorId)
                        ? TextButton(child: const Text('채택'), onPressed: () {
                      onAcceptAnswer(messageId, answer);
                      Navigator.pop(ctx);
                    }) : null,
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final senderNickname = data['senderNickname'] as String? ?? '이름없음';
    final question = data['message'] as String? ?? '';
    final isResolved = data['isResolved'] as bool? ?? false;
    final acceptedAnswer = data['acceptedAnswer'] as Map<String, dynamic>?;
    final answers = data['answers'] as List<dynamic>? ?? [];
    final questionAuthorId = data['senderId'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isResolved ? Colors.green.shade200 : Colors.blue.shade200, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isResolved ? Icons.check_circle : Icons.help, color: isResolved ? Colors.green : Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(isResolved ? '해결된 질문' : '질문', style: TextStyle(fontWeight: FontWeight.bold, color: isResolved ? Colors.green : Colors.blue)),
              const Spacer(),
              Text('작성자: $senderNickname', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Divider(height: 16),
          Text(question, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          if (isResolved && acceptedAnswer != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✔ 채택된 답변', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  const SizedBox(height: 4),
                  Text(acceptedAnswer['text']),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('답변자: ${acceptedAnswer['authorNickname']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  )
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (answers.isNotEmpty)
                TextButton(
                    onPressed: () => _showAllAnswers(context, answers, questionAuthorId),
                    child: Text('답변 ${answers.length}개 보기')
                ),
              if (!isResolved)
                ElevatedButton.icon(
                  onPressed: () => _showAnswerDialog(context),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('답변하기'),
                ),
            ],
          )
        ],
      ),
    );
  }
}

class _CheckInStatusMessage extends StatefulWidget {
  final DateTime validUntil;
  const _CheckInStatusMessage({required this.validUntil});

  @override
  State<_CheckInStatusMessage> createState() => _CheckInStatusMessageState();
}

class _CheckInStatusMessageState extends State<_CheckInStatusMessage> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemainingTime());
  }

  void _updateRemainingTime() {
    if (!mounted) return;
    final now = DateTime.now();
    final remaining = widget.validUntil.difference(now);

    setState(() {
      if (remaining.isNegative) {
        _isExpired = true;
        _remaining = Duration.zero;
        _timer?.cancel();
      } else {
        _isExpired = false;
        _remaining = remaining;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: _isExpired ? Colors.grey.shade300 : Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isExpired ? Colors.grey.shade300 : Colors.teal.shade200)
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isExpired ? Icons.cancel_outlined : Icons.check_circle,
              color: _isExpired ? Colors.grey.shade500 : Colors.teal,
              size: 20,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isExpired ? '마감된 출석체크입니다' : '출석체크가 진행 중입니다!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isExpired ? Colors.grey.shade600 : Colors.teal.shade800,
                  ),
                ),
                if (!_isExpired) ...[
                  const SizedBox(height: 2),
                  Text(
                    '마감까지 $minutes:$seconds 남음 (도구함에서 출석)',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// --- 4. 스터디 활동 분석 페이지 ---
// ===================================================================
class ActivityAnalysisPage extends StatefulWidget {
  final String studyId;
  const ActivityAnalysisPage({super.key, required this.studyId});

  @override
  State<ActivityAnalysisPage> createState() => _ActivityAnalysisPageState();
}

class _ActivityAnalysisPageState extends State<ActivityAnalysisPage> {
  Future<Map<String, dynamic>> _fetchReportData() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final firestore = FirebaseFirestore.instance;

    final studyDoc = await firestore.collection('studies').doc(widget.studyId).get();
    if (!studyDoc.exists) return {};
    final studyData = studyDoc.data()!;
    final memberUids = List<String>.from(studyData['members'] ?? []);
    final memberNicknames = List<String>.from(studyData['memberNicknames'] ?? []);
    final Map<String, String> uidToNickname = { for(var i=0; i < memberUids.length; i++) memberUids[i] : (i < memberNicknames.length ? memberNicknames[i] : 'uid-$i') };

    final msgSnapshot = await firestore.collection('chats').doc(widget.studyId).collection('messages')
        .where('timestamp', isGreaterThan: sevenDaysAgo).get();

    final checkInsSnapshot = await firestore.collection('studies').doc(widget.studyId).collection('check_ins')
        .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo).get();
    final totalCheckInDays = checkInsSnapshot.docs.length;

    final todosSnapshot = await firestore.collection('studies').doc(widget.studyId).collection('todos')
        .where('isDone', isEqualTo: true)
        .where('completedAt', isGreaterThan: sevenDaysAgo).get();
    final totalCompletedTodos = todosSnapshot.docs.length;

    int totalQaCount = 0;
    Map<String, int> memberContributions = { for (var name in memberNicknames) name : 0 };
    Map<String, int> memberAttendance = { for (var name in memberNicknames) name : 0 };

    for (var doc in msgSnapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId'] as String?;
      final nickname = uidToNickname[senderId];
      if (nickname != null) {
        if (data['messageType'] == 'question') {
          totalQaCount++;
          memberContributions[nickname] = (memberContributions[nickname] ?? 0) + 3; // 질문 3점
        } else if (data['messageType'] == 'text') {
          memberContributions[nickname] = (memberContributions[nickname] ?? 0) + 1; // 일반 메시지 1점
        }
        if (data.containsKey('answers') && (data['answers'] as List).isNotEmpty) {
          final answers = data['answers'] as List;
          totalQaCount += answers.length;
        }
      }
    }

    for (var doc in todosSnapshot.docs) {
      final completerId = doc.data()['completedById'] as String?;
      final nickname = uidToNickname[completerId];
      if (nickname != null) {
        memberContributions[nickname] = (memberContributions[nickname] ?? 0) + 5; // 할일 완료 5점
      }
    }

    for (var doc in checkInsSnapshot.docs) {
      final attendees = List.from(doc.data()['attendees'] ?? []);
      for (var attendee in attendees) {
        final uid = attendee['uid'] as String?;
        final nickname = uidToNickname[uid];
        if (nickname != null) {
          memberAttendance[nickname] = (memberAttendance[nickname] ?? 0) + 1;
        }
      }
    }

    final activityScores = {
      for (var name in memberNicknames) name: (memberContributions[name] ?? 0) + (memberAttendance[name] ?? 0) * 5
    };

    final sortedMembers = memberNicknames.toList()..sort((a,b) => activityScores[b]!.compareTo(activityScores[a]!));
    final mvp = sortedMembers.isNotEmpty ? sortedMembers.first : '없음';

    final totalPossibleAttendance = memberUids.length * totalCheckInDays;
    final totalActualAttendance = memberAttendance.values.fold(0, (prev, count) => prev + count);
    final attendanceRate = totalPossibleAttendance > 0 ? (totalActualAttendance / totalPossibleAttendance) * 100 : 0.0;

    return {
      'totalQaCount': totalQaCount,
      'totalCompletedTodos': totalCompletedTodos,
      'attendanceRate': attendanceRate,
      'mvp': mvp,
      'sortedMembers': sortedMembers,
      'activityScores': activityScores,
      'memberAttendance': memberAttendance,
      'totalCheckInDays': totalCheckInDays,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주간 스터디 리포트')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('리포트 데이터를 불러올 수 없습니다.'));
          }
          final report = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지난 7일간의 활동 요약', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildKpiGrid(report),
                const SizedBox(height: 24),
                _buildActivityChart(report),
                const SizedBox(height: 24),
                _buildAttendanceList(report),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> report) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _KpiCard(
          icon: Icons.question_answer,
          label: '질문/답변',
          value: report['totalQaCount'].toString(),
          color: Colors.blue,
        ),
        _KpiCard(
          icon: Icons.check_circle,
          label: '완료한 할 일',
          value: report['totalCompletedTodos'].toString(),
          color: Colors.deepPurple,
        ),
        _KpiCard(
          icon: Icons.pie_chart,
          label: '전체 출석률',
          value: '${report['attendanceRate'].toStringAsFixed(1)}%',
          color: Colors.green,
        ),
        _KpiCard(
          icon: Icons.star,
          label: '스터디 MVP',
          value: report['mvp'],
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildActivityChart(Map<String, dynamic> report) {
    final sortedMembers = report['sortedMembers'] as List<String>;
    final activityScores = report['activityScores'] as Map<String, int>;
    final maxScore = activityScores.values.fold(0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('멤버별 기여도 점수', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: sortedMembers.map((name) {
                final score = activityScores[name] ?? 0;
                final barWidthFactor = maxScore > 0 ? score / maxScore : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text(name, overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  Container(
                                    height: 20,
                                    width: constraints.maxWidth * barWidthFactor,
                                    decoration: BoxDecoration(
                                        color: Colors.teal.shade300,
                                        borderRadius: BorderRadius.circular(10)
                                    ),
                                  ),
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Text('$score 점', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      )
                                  )
                                ],
                              );
                            }
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList(Map<String, dynamic> report) {
    final sortedMembers = report['sortedMembers'] as List<String>;
    final memberAttendance = report['memberAttendance'] as Map<String, int>;
    final totalDays = report['totalCheckInDays'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('주간 출석 현황', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedMembers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final name = sortedMembers[index];
              final attendanceCount = memberAttendance[name] ?? 0;
              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                title: Text(name),
                trailing: Text('$attendanceCount / $totalDays 회', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                Icon(icon, color: color),
              ],
            ),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}


// ===================================================================
// --- 5. 방장 기능 페이지 ---
// ===================================================================
class _MemberStats {
  final int messageCount;
  final DateTime? lastSeen;
  _MemberStats({required this.messageCount, this.lastSeen});
}

class LeaderToolsPage extends StatefulWidget {
  final String studyId;
  const LeaderToolsPage({super.key, required this.studyId});

  @override
  State<LeaderToolsPage> createState() => _LeaderToolsPageState();
}

class _LeaderToolsPageState extends State<LeaderToolsPage> {

  Future<Map<String, dynamic>> _fetchManagementData() async {
    final firestore = FirebaseFirestore.instance;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final studyDoc = await firestore.collection('studies').doc(widget.studyId).get();
    if (!studyDoc.exists) return {};
    final studyData = studyDoc.data()!;

    final memberUids = List<String>.from(studyData['members'] ?? []);
    final memberNicknames = List<String>.from(studyData['memberNicknames'] ?? []);
    final leaderId = studyData['leaderId'];

    final msgSnapshot = await firestore.collection('chats').doc(widget.studyId).collection('messages')
        .where('timestamp', isGreaterThan: sevenDaysAgo)
        .orderBy('timestamp', descending: true)
        .get();

    Map<String, _MemberStats> memberStats = {};
    for (var uid in memberUids) {
      memberStats[uid] = _MemberStats(messageCount: 0, lastSeen: null);
    }

    for (var doc in msgSnapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId'] as String;
      if (memberStats.containsKey(senderId)) {
        int currentCount = memberStats[senderId]!.messageCount;
        memberStats[senderId] = _MemberStats(
          messageCount: currentCount + 1,
          lastSeen: memberStats[senderId]!.lastSeen ?? (data['timestamp'] as Timestamp).toDate(),
        );
      }
    }

    return {
      'nicknames': Map.fromIterables(memberUids, memberNicknames),
      'leaderId': leaderId,
      'stats': memberStats,
    };
  }

  Future<void> _updateApplicationStatus(String docId, String status, String applicantId, String applicantEmail, String applicantNickname) async {
    final firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();

    batch.update(firestore.collection('applications').doc(docId), {'status': status});

    if (status == 'accepted') {
      final studyRef = firestore.collection('studies').doc(widget.studyId);
      final studyDoc = await studyRef.get();
      if (!studyDoc.exists) return;

      final studyData = studyDoc.data()!;
      final maxMembers = studyData['maxMembers'];
      final newMemberCount = (studyData['memberCount'] ?? 0) + 1;

      batch.update(studyRef, {
        'members': FieldValue.arrayUnion([applicantId]),
        'memberNicknames': FieldValue.arrayUnion([applicantNickname]),
        'memberEmails': FieldValue.arrayUnion([applicantEmail]),
        'memberCount': FieldValue.increment(1),
      });

      if (newMemberCount >= maxMembers) {
        batch.update(studyRef, {'isRecruiting': false});
      }
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신청을 $status 처리했습니다.')));
    }
  }

  Future<void> _transferLeadership(String newLeaderId, String newLeaderNickname) async {
    await FirebaseFirestore.instance.collection('studies').doc(widget.studyId).update({
      'leaderId': newLeaderId,
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$newLeaderNickname 님에게 스터디장을 위임했습니다.')));
    }
  }

  Future<void> _removeMember(String memberId, String memberNickname) async {
    if (memberId == FirebaseAuth.instance.currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('자기 자신을 제외할 수 없습니다.')));
      return;
    }

    final studyRef = FirebaseFirestore.instance.collection('studies').doc(widget.studyId);
    final studyDoc = await studyRef.get();
    final members = List<String>.from(studyDoc.data()?['members'] ?? []);
    final emails = List<String>.from(studyDoc.data()?['memberEmails'] ?? []);
    final index = members.indexOf(memberId);
    final emailToRemove = (index != -1 && index < emails.length) ? emails[index] : null;

    await studyRef.update({
      'members': FieldValue.arrayRemove([memberId]),
      'memberNicknames': FieldValue.arrayRemove([memberNickname]),
      if(emailToRemove != null) 'memberEmails': FieldValue.arrayRemove([emailToRemove]),
      'memberCount': FieldValue.increment(-1),
    });

    if(mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$memberNickname 님을 스터디에서 제외했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스터디 관리')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildRecruitmentSection(),
            const Divider(thickness: 8),
            _buildApplicationSection(),
            const Divider(thickness: 8),
            _buildMemberManagementSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruitmentSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('studies').doc(widget.studyId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final isRecruiting = (snapshot.data!.data() as Map<String, dynamic>?)?['isRecruiting'] ?? false;
        return SwitchListTile(
          title: const Text('스터디원 모집', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(isRecruiting ? '현재 모집 중입니다. (검색에 노출됨)' : '현재 모집이 마감되었습니다.'),
          value: isRecruiting,
          onChanged: (val) {
            FirebaseFirestore.instance.collection('studies').doc(widget.studyId).update({'isRecruiting': val});
          },
        );
      },
    );
  }

  Widget _buildApplicationSection() {
    return ExpansionTile(
      leading: const Icon(Icons.person_add_alt_1),
      title: const Text('가입 신청 관리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('applications')
              .where('studyId', isEqualTo: widget.studyId)
              .where('status', isEqualTo: 'pending').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.docs.isEmpty) return const ListTile(title: Text('대기중인 신청자가 없습니다.'));

            return ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final applicantId = data['applicantId'];
                final applicantEmail = data['applicantEmail'];
                final applicantNickname = data['applicantNickname'] ?? applicantEmail.split('@')[0];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(applicantNickname),
                    subtitle: Text(applicantEmail),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.check, color: Colors.green), tooltip: '수락', onPressed: () => _updateApplicationStatus(doc.id, 'accepted', applicantId, applicantEmail, applicantNickname)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red), tooltip: '거절', onPressed: () => _updateApplicationStatus(doc.id, 'rejected', applicantId, applicantEmail, applicantNickname)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberManagementSection() {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.group),
      title: const Text('스터디 멤버 관리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _fetchManagementData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const ListTile(title: Text('멤버 정보를 불러올 수 없습니다.'));

            final nicknames = snapshot.data!['nicknames'] as Map<String, String>;
            final leaderId = snapshot.data!['leaderId'] as String;
            final stats = snapshot.data!['stats'] as Map<String, _MemberStats>;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: nicknames.length,
              itemBuilder: (context, index) {
                final uid = nicknames.keys.elementAt(index);
                final nickname = nicknames[uid]!;
                final memberStat = stats[uid]!;
                final isCurrentLeader = uid == leaderId;

                String subtitleText;
                if(memberStat.lastSeen != null) {
                  subtitleText = '최근 활동: ${DateFormat('yy/MM/dd').format(memberStat.lastSeen!)} | 주간 메시지: ${memberStat.messageCount}개';
                } else {
                  subtitleText = '최근 활동 없음';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(nickname.isNotEmpty ? nickname[0].toUpperCase() : '?')),
                    title: Row(
                      children: [
                        Text(nickname),
                        if (isCurrentLeader) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.stars, color: Colors.amber, size: 16),
                        ]
                      ],
                    ),
                    subtitle: Text(subtitleText),
                    trailing: isCurrentLeader ? null : IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.military_tech_outlined),
                                title: const Text('스터디장으로 지정'),
                                onTap: () => _transferLeadership(uid, nickname),
                              ),
                              ListTile(
                                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                                title: const Text('스터디에서 제외하기', style: TextStyle(color: Colors.red)),
                                onTap: () => _removeMember(uid, nickname),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}