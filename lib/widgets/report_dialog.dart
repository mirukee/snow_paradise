import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/report_service.dart';
import '../providers/user_service.dart'; // To get current user

class ReportDialog extends StatefulWidget {
  final String targetUid;
  final String targetContentId; // Can be user ID if reporting a user profile directly
  final String reportType; // 'user' or 'product' or 'chat'

  const ReportDialog({
    super.key,
    required this.targetUid,
    required this.targetContentId,
    this.reportType = 'user',
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _reasons = [
    '스팸 / 부적절한 홍보',
    '욕설 / 비하 발언',
    '사기 의심',
    '음란성 / 부적절한 콘텐츠',
    '거래 금지 물품 등록',
    '기타 사유',
  ];
  String? _selectedReason;
  bool _isLoading = false;

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    final currentUser = context.read<UserService>().currentUser;
    if (currentUser == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<ReportService>().reportItem(
            reporterUid: currentUser.uid,
            targetUid: widget.targetUid,
            targetContentId: widget.targetContentId,
            reason: _selectedReason!,
            // type: widget.reportType, // If ReportService supports type later
          );
      if (!mounted) return;
      
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고가 접수되었습니다. 관리자 검토 후 조치됩니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('신고하기', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('신고 사유를 선택해주세요:'),
            const SizedBox(height: 12),
            ..._reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF3E97EA),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        FilledButton(
          onPressed: (_isLoading || _selectedReason == null) ? null : _submitReport,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3E97EA),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('제출'),
        ),
      ],
    );
  }
}
