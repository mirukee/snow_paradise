import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class HeicConverter {
  static Future<Uint8List?> convertToJpeg(XFile file) async {
    // 파일 이름이 .heic나 .heif로 끝나는지 확인
    final name = file.name.toLowerCase();
    if (!name.endsWith('.heic') && !name.endsWith('.heif')) {
      return null; // HEIC가 아니면 처리 안 함
    }

    try {
      // XFile에서 바이트 읽기
      final bytes = await file.readAsBytes();
      debugPrint('HeicConverterWeb: Read ${bytes.length} bytes from ${file.name}');
      
      if (bytes.isEmpty) {
        debugPrint('HeicConverterWeb: File is empty');
        return null;
      }

      // 바이트를 Blob으로 변환 (MIME type 명시 필요)
      final blob = html.Blob([bytes], 'image/heic');
      
      // index.html에 정의된 JS 함수 호출
      // convertHeicToJpeg(blob) -> Promise<Blob>
      final promise = js.context.callMethod('convertHeicToJpeg', [blob]);
      if (promise == null) {
        return null;
      }

      final jsPromise = js.JsObject.fromBrowserObject(promise);
      if (!jsPromise.hasProperty('then')) {
        return null;
      }

      final completer = Completer<html.Blob?>();
      final onResolve = js.JsFunction.withThis((_, result) {
        if (!completer.isCompleted) {
          completer.complete(result is html.Blob ? result : null);
        }
      });
      final onReject = js.JsFunction.withThis((_, error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });
      jsPromise.callMethod('then', [onResolve, onReject]);

      final resultBlob = await completer.future;
      if (resultBlob == null) {
        return null;
      }

      // Blob을 Uint8List로 변환
      final reader = html.FileReader();
      reader.readAsArrayBuffer(resultBlob);
      await reader.onLoad.first;
      return reader.result as Uint8List;
    } catch (e) {
      debugPrint('HEIC conversion error: $e');
    }
    return null;
  }
}
