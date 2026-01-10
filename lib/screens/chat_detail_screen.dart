import 'package:flutter/material.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  
  final List<Map<String, dynamic>> _messages = [
    {'message': '안녕하세요! 이 상품 아직 있나요?', 'isMe': false, 'time': '오후 2:00'},
    {'message': '네 안녕하세요~ 판매 중입니다.', 'isMe': true, 'time': '오후 2:05'},
    {'message': '직거래 가능한가요?', 'isMe': false, 'time': '오후 2:10'},
  ];

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'message': _controller.text,
        'isMe': true, 
        'time': '방금',
      });
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // [핵심] main.dart에서 설정한 메인 색상을 가져옵니다.
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('보더1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['isMe'];
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      // [수정] 내 말풍선 색상을 테마 색상으로 변경
                      color: isMe ? primaryColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                        bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                      ),
                    ),
                    child: Text(
                      msg['message'],
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 16, right: 8, bottom: 30, top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {}, 
                  icon: const Icon(Icons.add, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '메시지 보내기',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                // [수정] 전송 버튼 색상도 테마 색상으로 변경
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send, color: primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}