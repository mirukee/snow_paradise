import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatDetailScreen extends StatelessWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
  });

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final chatService = context.read<ChatService>();

    return FutureBuilder<ChatRoom?>(
      future: chatService.getChatRoomById(chatId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('채팅방 정보를 불러오지 못했어요.')),
          );
        }

        final room = snapshot.data;
        if (room == null) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('채팅방을 찾을 수 없습니다.')),
          );
        }

        return ChatScreen(room: room);
      },
    );
  }
}
