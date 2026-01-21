import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_tab.dart';
import 'shop_screen.dart';
import 'sell_screen.dart';
import 'chat_list_screen.dart';
import 'my_screen.dart';
import '../providers/main_tab_provider.dart';
import '../providers/user_service.dart';
import '../services/chat_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static const List<Widget> _screens = [
    HomeTab(),
    ShopScreen(),
    SellScreen(),
    ChatListScreen(),
    MyScreen(),
  ];

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Stream<int>? _unreadCountStream;
  String? _unreadStreamUserId;

  void _syncUnreadStream(
    ChatService chatService,
    String? currentUserId,
  ) {
    if (_unreadCountStream == null || _unreadStreamUserId != currentUserId) {
      _unreadStreamUserId = currentUserId;
      _unreadCountStream = chatService.getTotalUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<MainTabProvider>().currentIndex;
    final currentUser = context.watch<UserService>().currentUser;
    final chatService = context.read<ChatService>();
    _syncUnreadStream(chatService, currentUser?.uid);

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: currentIndex,
        children: MainScreen._screens,
      ),
      bottomNavigationBar: currentUser == null
          ? _buildBottomNavigationBar(
              context,
              currentIndex,
              null,
            )
          : StreamBuilder<int>(
              stream: _unreadCountStream,
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

  Widget _buildBottomNavigationBar(
    BuildContext context,
    int currentIndex,
    int? unreadCount,
  ) {
    const barHeight = 76.0;
    const iceBlue = Color(0xFF00AEEF);
    const deepNavy = Color(0xFF101922);
    const inactiveColor = Color(0xFF94A3B8);

    Widget buildChatIcon(bool isSelected) {
      final showBadge = unreadCount != null && unreadCount > 0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline),
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

    void handleTap(int index) {
      context.read<MainTabProvider>().setIndex(index);
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      currentIndex: currentIndex,
                      label: '홈',
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      activeColor: deepNavy,
                      inactiveColor: inactiveColor,
                      onTap: () => handleTap(0),
                    ),
                    _buildNavItem(
                      index: 1,
                      currentIndex: currentIndex,
                      label: '쇼핑',
                      icon: Icons.search_outlined,
                      activeIcon: Icons.search,
                      activeColor: deepNavy,
                      inactiveColor: inactiveColor,
                      onTap: () => handleTap(1),
                    ),
                    _buildCenterLabel(
                      isSelected: currentIndex == 2,
                      activeColor: deepNavy,
                      inactiveColor: inactiveColor,
                    ),
                    _buildNavItem(
                      index: 3,
                      currentIndex: currentIndex,
                      label: '채팅',
                      icon: Icons.chat_bubble_outline,
                      activeIcon: Icons.chat_bubble,
                      activeColor: deepNavy,
                      inactiveColor: inactiveColor,
                      onTap: () => handleTap(3),
                      iconBuilder: buildChatIcon,
                    ),
                    _buildNavItem(
                      index: 4,
                      currentIndex: currentIndex,
                      label: '마이',
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      activeColor: deepNavy,
                      inactiveColor: inactiveColor,
                      onTap: () => handleTap(4),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -16,
              left: 0,
              right: 0,
              child: Center(
                child: _buildCenterButton(
                  onTap: () => handleTap(2),
                  backgroundColor: deepNavy,
                  iconColor: iceBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
    Widget Function(bool isSelected)? iconBuilder,
  }) {
    final isSelected = index == currentIndex;
    final color = isSelected ? activeColor : inactiveColor;
    final iconWidget =
        iconBuilder?.call(isSelected) ?? Icon(isSelected ? activeIcon : icon);

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconTheme(
              data: IconThemeData(color: color, size: 24),
              child: iconWidget,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterLabel({
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final color = isSelected ? activeColor : inactiveColor;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 18),
          Text(
            '등록',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterButton({
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Material(
      color: backgroundColor,
      elevation: 10,
      shadowColor: backgroundColor.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Icon(
            Icons.add,
            color: iconColor,
            size: 28,
          ),
        ),
      ),
    );
  }
}
