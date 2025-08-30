import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase 초기화
  runApp(const MyApp());
}

/// MyApp: 기본 MaterialApp 구성
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스터디 그룹 채팅',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.teal[50],
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          surfaceTint: Colors.transparent,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

/// ChatMessage 모델 (Firestore에서 매핑용)
class ChatMessage {
  final String sender;
  final String message;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.sender,
    required this.message,
    required this.timestamp,
    this.isMe = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data, {bool isMe = false}) {
    return ChatMessage(
      sender: data['sender'] ?? 'Unknown',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMe: isMe,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'message': message,
      'timestamp': timestamp,
    };
  }
}

/// ChatScreen
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final firestore = FirebaseFirestore.instance;

  // 참가자 목록 및 출석 기록 (로컬)
  final Map<String, DateTime?> _attendanceRecords = {
    "나": null,
    "김호현": null,
    "민재홍": null,
    "오은수": null,
  };

  String _roomLeader = "나"; // 기본 방장

  final Map<String, Map<String, bool>> _dailyAttendanceRecords = {
    "2025-03-19": {
      "나": true,
      "김호현": true,
      "민재홍": true,
      "오은수": true,
    },
    "2025-03-26": {
      "나": true,
      "김호현": true,
      "민재홍": false,
      "오은수": true,
    },
    "2025-04-02": {
      "나": true,
      "김호현": true,
      "민재홍": true,
      "오은수": false,
    },
  };

  /// Firestore 메시지 전송
  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    await firestore.collection("messages").add({
      'sender': '나',
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _textController.clear();
  }

  /// 메시지 버블 UI
  Widget _buildChatBubble(ChatMessage message) {
    final bool isMe = message.isMe;
    final bubbleColor = isMe ? Colors.teal[300] : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe)
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Text(
                    message.sender.substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
              if (isMe)
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Text(
                    message.sender.substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(message.timestamp),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 입력창
  Widget _buildTextComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration.collapsed(
                  hintText: "메시지를 입력하세요"),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.teal),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }

  /// 방장 넘기기
  void _transferRoomLeader() {
    List<String> candidates =
    _attendanceRecords.keys.where((name) => name != _roomLeader).toList();
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("새로운 방장을 선택하세요"),
          children: candidates.map((candidate) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() {
                  _roomLeader = candidate;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("방장이 $candidate 으로 변경되었습니다.")),
                );
              },
              child: Text(candidate),
            );
          }).toList(),
        );
      },
    );
  }

  /// 그룹 정보/출석 대화상자
  void _showGroupAndAttendanceInfo() {
    final List<String> sortedDates = _dailyAttendanceRecords.keys.toList()..sort();
    final List<String> participants = _attendanceRecords.keys.toList();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("스터디 그룹 정보 및 출석 체크"),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("모임 시간: 매주 수요일 오후 7시"),
                  const Text("장소: 부산 서면"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("방장: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_roomLeader, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (_roomLeader == "나")
                        TextButton(
                          onPressed: _transferRoomLeader,
                          child: const Text("방장 넘기기"),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("참여자:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("- 김호현"),
                  const Text("- 민재홍"),
                  const Text("- 오은수"),
                  const SizedBox(height: 16),
                  const Text("개별 출석 체크 내역", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 40,
                    dataRowHeight: 48,
                    columns: const [
                      DataColumn(label: Text("이름")),
                      DataColumn(label: Text("출석 여부")),
                      DataColumn(label: Text("출석 시간")),
                    ],
                    rows: _attendanceRecords.entries.map((entry) {
                      final name = entry.key;
                      final time = entry.value;
                      final displayName = (name == _roomLeader) ? "$name (방장)" : name;
                      final isChecked = time != null;
                      final timeStr = isChecked ? DateFormat('HH:mm').format(time!) : "";
                      return DataRow(
                        cells: [
                          DataCell(Text(displayName)),
                          DataCell(
                            Switch(
                              activeColor: Colors.teal,
                              value: isChecked,
                              onChanged: (bool val) {
                                setState(() {
                                  if (val) {
                                    _attendanceRecords[name] = DateTime.now();
                                  } else {
                                    _attendanceRecords[name] = null;
                                  }
                                });
                              },
                            ),
                          ),
                          DataCell(Text(timeStr)),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text("일간 출석표", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowHeight: 40,
                      dataRowHeight: 40,
                      columns: [
                        const DataColumn(label: Text("이름")),
                        for (var date in sortedDates)
                          DataColumn(label: Text(date)),
                      ],
                      rows: participants.map((name) {
                        return DataRow(
                          cells: [
                            DataCell(Text(name)),
                            for (var date in sortedDates)
                              DataCell(Text(
                                _dailyAttendanceRecords[date]?[name] == true ? "O" : "X",
                              )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("닫기"),
            ),
          ],
        );
      },
    );
  }

  /// 출석 체크
  void _checkAttendance() {
    if (_roomLeader == "나") {
      setState(() {
        _attendanceRecords.updateAll((key, value) => DateTime.now());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("전체 출석 체크가 완료되었습니다.")),
      );
    } else {
      setState(() {
        if (_attendanceRecords["나"] == null) {
          _attendanceRecords["나"] = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("출석 체크가 완료되었습니다.")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("이미 출석 체크가 완료되었습니다.")),
          );
        }
      });
    }
    _showGroupAndAttendanceInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("스터디 그룹 채팅"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: "그룹 정보 보기",
            onPressed: _showGroupAndAttendanceInfo,
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: "출석 체크",
            onPressed: _checkAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection("messages")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final msg = ChatMessage.fromMap(
                      data,
                      isMe: data['sender'] == "나",
                    );
                    return _buildChatBubble(msg);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildTextComposer(),
        ],
      ),
    );
  }
}
