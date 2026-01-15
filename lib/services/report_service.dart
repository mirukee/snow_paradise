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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
