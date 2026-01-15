import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_tab.dart';
import 'shop_screen.dart';
import 'sell_screen.dart';
import 'chat_list_screen.dart';
import 'my_screen.dart';
import 'search_screen.dart';
import '../providers/main_tab_provider.dart';
import '../providers/user_service.dart';
import '../services/chat_service.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  static const List<Widget> _screens = [
    HomeTab(),
    ShopScreen(),
    SellScreen(),
    ChatListScreen(),
    MyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<MainTabProvider>().currentIndex;
    final currentUser = context.watch<UserService>().currentUser;
    final chatService = context.read<ChatService>();

    return Scaffold(
      backgroundColor: Colors.white,
      // 홈 탭에서만 검색 아이콘을 노출
      appBar: currentIndex == 0
          ? AppBar(
              automaticallyImplyLeading: false,
              title: const SizedBox.shrink(),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: currentUser == null
          ? _buildBottomNavigationBar(
              context,
              currentIndex,
              null,
            )
          : StreamBuilder<int>(
              stream: chatService.getTotalUnreadCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return _buildBottomNavigationBar(
                  context,
                  currentIndex,
                  unreadCount,
                );
              },
            ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar(
    BuildContext context,
    int currentIndex,
    int? unreadCount,
  ) {
    Widget buildChatIcon(IconData iconData) {
      final showBadge = unreadCount != null && unreadCount > 0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(iconData),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
    }

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) {
        context.read<MainTabProvider>().setIndex(index);
      },
      backgroundColor: Colors.white,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      elevation: 0,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: '홈',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: '쇼핑',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: '등록',
        ),
        BottomNavigationBarItem(
          icon: buildChatIcon(Icons.chat_bubble_outline),
          activeIcon: buildChatIcon(Icons.chat_bubble),
          label: '채팅',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: '마이',
        ),
      ],
    );
  }
}
