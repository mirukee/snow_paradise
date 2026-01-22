import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/report_service.dart';

/// 관리자용 신고 목록 화면
/// 신고 상태 필터링, 해결/삭제 액션 지원
class AdminReportListScreen extends StatefulWidget {
  const AdminReportListScreen({super.key});

  @override
  State<AdminReportListScreen> createState() => _AdminReportListScreenState();
}

class _AdminReportListScreenState extends State<AdminReportListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportService _reportService = ReportService();

  // 필터 상태: null=전체, 'pending'=대기, 'resolved'=해결
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _statusFilter = null; // 전체
            break;
          case 1:
            _statusFilter = 'pending'; // 대기
            break;
          case 2:
            _statusFilter = 'resolved'; // 해결
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 신고 해결 처리
  Future<void> _handleResolve(String reportId) async {
    try {
      await _reportService.updateReportStatus(reportId, 'resolved');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고가 해결됨으로 처리되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('처리 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 신고 삭제 처리
  Future<void> _handleDelete(String reportId) async {
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('신고 삭제'),
        content: const Text('이 신고를 삭제하시겠습니까?\n삭제된 신고는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reportService.deleteReport(reportId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신고가 삭제되었습니다.'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상태 필터 탭
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF3E97EA),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF3E97EA),
            tabs: const [
              Tab(text: '전체'),
              Tab(text: '대기'),
              Tab(text: '해결'),
            ],
          ),
        ),
        // 신고 목록
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _statusFilter == null
                            ? '접수된 신고가 없습니다.'
                            : _statusFilter == 'pending'
                                ? '대기 중인 신고가 없습니다.'
                                : '해결된 신고가 없습니다.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildReportCard(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('reports');

    if (_statusFilter != null) {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildReportCard(String docId, Map<String, dynamic> data) {
    final reporterUid = data['reporterUid'] ?? 'Unknown';
    final targetUid = data['targetUid'] ?? 'Unknown';
    final reason = data['reason'] ?? 'No reason';
    final status = data['status'] ?? 'pending';

    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate())
        : '-';

    final isPending = status == 'pending';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 상태 뱃지 + 날짜
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBadge(status),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 신고 사유
            Text(
              reason,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101922),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // 신고자/대상자 정보
            _buildInfoRow(Icons.person, '신고자', reporterUid),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.person_off, '대상자', targetUid),
            const SizedBox(height: 16),
            // 액션 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 해결 버튼 (대기 상태일 때만)
                if (isPending)
                  ElevatedButton.icon(
                    onPressed: () => _handleResolve(docId),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('해결됨'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                const SizedBox(width: 8),
                // 삭제 버튼
                OutlinedButton.icon(
                  onPressed: () => _handleDelete(docId),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('삭제'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isPending = status == 'pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPending ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPending ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.pending_outlined : Icons.check_circle_outline,
            size: 14,
            color: isPending ? Colors.red[700] : Colors.green[700],
          ),
          const SizedBox(width: 4),
          Text(
            isPending ? '대기' : '해결됨',
            style: TextStyle(
              color: isPending ? Colors.red[700] : Colors.green[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF101922),
              fontSize: 14,
              fontFamily: 'Monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
