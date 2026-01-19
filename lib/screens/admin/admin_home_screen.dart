import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 관리자 대시보드 홈 화면
/// 총 사용자, 총 상품, 대기 중 신고, 오늘 등록 상품 통계 표시
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF101922);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            const Text(
              '대시보드',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '서비스 현황을 한눈에 확인하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            // 통계 카드 그리드
            LayoutBuilder(
              builder: (context, constraints) {
                // 반응형: 너비에 따라 2열 또는 4열
                final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard(
                      icon: Icons.people,
                      iconColor: Colors.blue,
                      title: '총 사용자',
                      streamBuilder: _buildUserCountStream(),
                    ),
                    _buildStatCard(
                      icon: Icons.shopping_bag,
                      iconColor: Colors.green,
                      title: '총 상품',
                      streamBuilder: _buildProductCountStream(),
                    ),
                    _buildStatCard(
                      icon: Icons.report_problem,
                      iconColor: Colors.orange,
                      title: '대기 중 신고',
                      streamBuilder: _buildPendingReportCountStream(),
                    ),
                    _buildStatCard(
                      icon: Icons.today,
                      iconColor: Colors.purple,
                      title: '오늘 등록 상품',
                      streamBuilder: _buildTodayProductCountStream(),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            // 최근 활동 섹션 (간단한 안내)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '좌측 메뉴에서 사용자, 상품, 신고를 관리할 수 있습니다.',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 통계 카드 위젯
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget streamBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 아이콘
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const Spacer(),
          // 숫자
          streamBuilder,
          const SizedBox(height: 4),
          // 제목
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 총 사용자 수 스트림
  Widget _buildUserCountStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        );
      },
    );
  }

  /// 총 상품 수 스트림
  Widget _buildProductCountStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        );
      },
    );
  }

  /// 대기 중 신고 수 스트림
  Widget _buildPendingReportCountStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
        }
        final count = snapshot.data!.docs.length;
        return Text(
          '$count',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: count > 0 ? Colors.orange : textDark,
          ),
        );
      },
    );
  }

  /// 오늘 등록 상품 수 스트림
  Widget _buildTodayProductCountStream() {
    // 오늘 00:00:00 기준
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayTimestamp = Timestamp.fromDate(todayStart);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('createdAt', isGreaterThanOrEqualTo: todayTimestamp)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('--', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
        }
        return Text(
          '${snapshot.data!.docs.length}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        );
      },
    );
  }
}
