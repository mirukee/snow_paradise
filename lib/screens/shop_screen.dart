import 'package:flutter/material.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  // 카테고리 데이터
  final List<Map<String, dynamic>> categories = const [
    {'title': '스키', 'icon': Icons.downhill_skiing},
    {'title': '스노우보드', 'icon': Icons.snowboarding},
    {'title': '의류', 'icon': Icons.checkroom},
    {'title': '장비/보호구', 'icon': Icons.shield}, // 헬멧, 보호대 등
    {'title': '시즌권', 'icon': Icons.confirmation_number},
    {'title': '시즌방', 'icon': Icons.home},
    {'title': '강습', 'icon': Icons.school},
    {'title': '기타', 'icon': Icons.more_horiz},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '카테고리',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // 탭 화면이므로 뒤로가기 숨김
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 한 줄에 2개씩
            mainAxisSpacing: 16, // 세로 간격
            crossAxisSpacing: 16, // 가로 간격
            childAspectRatio: 1.5, // 가로가 조금 더 긴 직사각형 (비율 조절 가능)
          ),
          itemBuilder: (context, index) {
            return _buildCategoryCard(context, categories[index]);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    return InkWell(
      onTap: () {
        // 나중에 리스트 화면으로 이동
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category['title']} 보러가기 (준비 중)')),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50], // 아주 연한 회색 배경
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘 원형 배경
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1), // 테마색 연하게
                shape: BoxShape.circle,
              ),
              child: Icon(
                category['icon'],
                size: 32,
                color: Theme.of(context).primaryColor, // 테마색 진하게
              ),
            ),
            const SizedBox(height: 12),
            // 카테고리 이름
            Text(
              category['title'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}