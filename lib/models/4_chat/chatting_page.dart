import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'study_tools_drawer.dart';
import 'leader_tools_page.dart';
// ### FIXED: 이름이 변경된 StudyDashboardPage 클래스가 있는 파일을 import ###
import 'activity_analysis_page.dart';

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

    WriteBatch batch = _firestore.batch();

    final messageRef = _firestore.collection('chats').doc(widget.studyId).collection('messages').doc(messageId);
    batch.update(messageRef, {'answers': FieldValue.arrayUnion([answer])});

    final userRef = _firestore.collection('users').doc(currentUser.uid);
    batch.update(userRef, {'growthIndex': FieldValue.increment(10)});

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🤝 답변을 등록했습니다. +10 포인트를 얻었습니다!'))
      );
    }
  }

  Future<void> _acceptAnswer(String messageId, Map<String, dynamic> answer) async {
    final answererId = answer['authorId'] as String?;
    if (answererId == null) return;

    WriteBatch batch = _firestore.batch();

    final messageRef = _firestore.collection('chats').doc(widget.studyId).collection('messages').doc(messageId);
    batch.update(messageRef, {
      'isResolved': true,
      'acceptedAnswer': answer,
    });

    final userRef = _firestore.collection('users').doc(answererId);
    batch.update(userRef, {'growthIndex': FieldValue.increment(20)});

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🏆 답변이 채택되었습니다! 답변자가 +20 포인트를 얻었습니다.'))
      );
    }
  }

  Future<void> _leaveStudy() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🏃‍♀️ 스터디 포기'),
        content: const Text('정말로 스터디를 포기하시겠습니까?\n패널티로 50 포인트가 차감됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('포기하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (isConfirmed != true) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    try {
      WriteBatch batch = _firestore.batch();

      final studyRef = _firestore.collection('studies').doc(widget.studyId);
      batch.update(studyRef, {
        'members': FieldValue.arrayRemove([currentUser.uid]),
        'memberNicknames': FieldValue.arrayRemove([_currentUserNickname]),
        'memberCount': FieldValue.increment(-1),
      });

      final userRef = _firestore.collection('users').doc(currentUser.uid);
      batch.update(userRef, {'growthIndex': FieldValue.increment(-50)});

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스터디를 포기했습니다. -50 포인트가 차감됩니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('스터디 포기 중 오류 발생: $e')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isLeader = _auth.currentUser?.uid == _leaderId;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(widget.studyTitle),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                tooltip: "스터디 도구함",
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'dashboard':
                // ### FIXED: 클래스 이름을 StudyDashboardPage로 수정 ###
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StudyDashboardPage(studyId: widget.studyId)));
                  break;
                case 'leader_tools':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderToolsPage(studyId: widget.studyId)));
                  break;
                case 'leave_study':
                  _leaveStudy();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'dashboard',
                  child: ListTile(leading: Icon(Icons.dashboard_outlined), title: Text('스터디 대시보드')),
                ),
                if (isLeader)
                  const PopupMenuItem<String>(
                    value: 'leader_tools',
                    child: ListTile(leading: Icon(Icons.admin_panel_settings_outlined), title: Text('스터디장 도구')),
                  ),
                if (!isLeader && _leaderId.isNotEmpty)
                  const PopupMenuItem<String>(
                    value: 'leave_study',
                    child: ListTile(leading: Icon(Icons.exit_to_app, color: Colors.red), title: Text('스터디 포기하기', style: TextStyle(color: Colors.red))),
                  ),
              ];
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
                        messageWidget = _PollMessage(key: ValueKey(doc.id), messageId: doc.id, data: data, studyId: widget.studyId);
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
  final String studyId;
  final String messageId;
  final Map<String, dynamic> data;
  const _PollMessage({super.key, required this.studyId, required this.messageId, required this.data});

  @override
  State<_PollMessage> createState() => __PollMessageState();
}

class __PollMessageState extends State<_PollMessage> {

  Future<void> _vote(String option) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final docRef = FirebaseFirestore.instance.collection('chats').doc(widget.studyId).collection('messages').doc(widget.messageId);

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text('투표', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
              const Spacer(),
              Text('작성자: $senderNickname', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Divider(height: 20),
          Text(question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...options.entries.map((entry) {
            final optionText = entry.key;
            final voters = entry.value as List;
            final voteCount = voters.length;
            final percentage = totalVotes == 0 ? 0.0 : (voteCount / totalVotes);
            final bool isMyVote = myVote == optionText;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: InkWell(
                onTap: () => _vote(optionText),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: isMyVote ? Colors.teal.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isMyVote ? Colors.teal : Colors.grey.shade300)
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(isMyVote ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.teal, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(optionText, style: TextStyle(fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal))),
                          Text('$voteCount표', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[200],
                          color: Colors.teal.shade200,
                        ),
                      ),
                    ],
                  ),
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
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isResolved ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isResolved ? Icons.check_circle_rounded : Icons.help_rounded, color: isResolved ? Colors.green : Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(isResolved ? '해결된 질문' : '질문', style: TextStyle(fontWeight: FontWeight.bold, color: isResolved ? Colors.green.shade800 : Colors.blue.shade800)),
              const Spacer(),
              Text('작성자: $senderNickname', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Divider(height: 20),
          Text(question, style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 12),
          if (isResolved && acceptedAnswer != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✔︎ 채택된 답변', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  const SizedBox(height: 8),
                  Text(acceptedAnswer['text'], style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('답변자: ${acceptedAnswer['authorNickname']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  )
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (answers.isNotEmpty)
                TextButton(
                    onPressed: () => _showAllAnswers(context, answers, questionAuthorId),
                    child: Text('답변 ${answers.length}개 보기')
                ),
              if (!isResolved)
                ElevatedButton(
                  onPressed: () => _showAnswerDialog(context),
                  child: const Text('답변하기'),
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
          borderRadius: BorderRadius.circular(20),
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
            Text(
              _isExpired ? '마감된 출석체크' : '출석체크 진행 중! ($minutes:$seconds)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isExpired ? Colors.grey.shade600 : Colors.teal.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

