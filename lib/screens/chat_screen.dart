import 'package:flutter/material.dart';
import 'chat_detail_screen.dart'; // 곧 만들 파일

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '채팅',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false, // 왼쪽 정렬 (안드로이드/iOS 통일감)
        automaticallyImplyLeading: false, // 뒤로가기 버튼 숨김 (탭 화면이므로)
      ),
      body: ListView.separated(
        itemCount: 5, // 샘플 데이터 5개
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return ListTile(
            onTap: () {
              // 채팅방으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatDetailScreen()),
              );
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // 프로필 이미지
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: const NetworkImage('https://picsum.photos/100/100'), // 랜덤 이미지
                ),
                // 온라인 상태 표시 (짝수번째만)
                if (index % 2 == 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            // 이름과 시간
            title: Row(
              children: [
                Text(
                  '보더$index',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 4),
                Text(
                  '다산동 · ${index + 1}분 전',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            // 마지막 메시지 내용
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '안녕하세요! 살로몬 데크 구매하고 싶은데 네고 가능할까요?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            // 상품 썸네일 (오른쪽 끝)
            trailing: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                'https://picsum.photos/100/100?random=$index',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}