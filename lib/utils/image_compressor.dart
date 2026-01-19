import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'heic_converter.dart';

class ImageCompressor {
  /// XFile을 받아 JPEG 포맷의 바이트로 변환 및 압축하여 반환
  static Future<Uint8List?> compressImage(XFile file) async {
    // 1. HEIC 변환 시도 (Web 전용, Mobile은 null 반환)
    final heicBytes = await HeicConverter.convertToJpeg(file);
    if (heicBytes != null) {
      return heicBytes;
    }

    final bytes = await file.readAsBytes();
    
    // Web이고 HEIC 파일인데 변환 실패했다면, 
    // flutter_image_compress도 실패할 것이므로(브라우저가 못읽음)
    // 원본 데이터를 그대로 반환 (업로드는 되게 함)
    final name = file.name.toLowerCase();
    if (kIsWeb && (name.endsWith('.heic') || name.endsWith('.heif'))) {
      debugPrint('ImageCompressor: HEIC conversion failed on Web. Returning original bytes.');
      return bytes;
    }

    // Web의 경우 flutter_image_compress가 내부적으로 canvas 등을 이용하여 변환 시도
    // 모바일의 경우 네이티브 API 사용
    // 품질 90으로 JPEG 변환 (HEIC 등도 JPEG로 변환됨)
    try {
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 90,
        format: CompressFormat.jpeg,
      );
      return compressedBytes;
    } catch (e) {
      debugPrint('ImageCompressor: Compression failed ($e). Returning original bytes.');
      return bytes; // 압축 실패 시 원본 반환
    }

  }
}
