import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  ReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> reportItem({
    required String reporterUid,
    required String targetUid,
    required String targetContentId,
    required String reason,
  }) async {
    final trimmedReporter = reporterUid.trim();
    final trimmedTarget = targetUid.trim();
    final trimmedContentId = targetContentId.trim();
    final trimmedReason = reason.trim();

    if (trimmedReporter.isEmpty ||
        trimmedTarget.isEmpty ||
        trimmedContentId.isEmpty) {
      throw StateError('신고 정보를 찾을 수 없습니다.');
    }
    if (trimmedReason.isEmpty) {
      throw StateError('신고 사유를 입력해 주세요.');
    }

    await _firestore.collection('reports').add({
      'reporterUid': trimmedReporter,
      'targetUid': trimmedTarget,
      'targetContentId': trimmedContentId,
      'reason': trimmedReason,
      'status': 'pending', // 신고 상태: pending, resolved
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 신고 상태 업데이트 (pending → resolved)
  Future<void> updateReportStatus(String reportId, String status) async {
    final trimmedId = reportId.trim();
    if (trimmedId.isEmpty) {
      throw StateError('신고 ID가 유효하지 않습니다.');
    }

    final validStatuses = ['pending', 'resolved'];
    if (!validStatuses.contains(status)) {
      throw StateError('유효하지 않은 상태값입니다.');
    }

    await _firestore.collection('reports').doc(trimmedId).update({
      'status': status,
      'resolvedAt': status == 'resolved' ? FieldValue.serverTimestamp() : null,
    });
  }

  /// 신고 삭제
  Future<void> deleteReport(String reportId) async {
    final trimmedId = reportId.trim();
    if (trimmedId.isEmpty) {
      throw StateError('신고 ID가 유효하지 않습니다.');
    }

    await _firestore.collection('reports').doc(trimmedId).delete();
  }

  /// 신고 목록 스트림 (상태 필터 지원)
  Stream<QuerySnapshot> getReportsStream({String? statusFilter}) {
    Query query = _firestore.collection('reports');
    
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }
}
