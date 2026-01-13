import 'package:firebase_storage/firebase_storage.dart';

import 'storage_uploader_stub.dart'
    if (dart.library.io) 'storage_uploader_io.dart';

Future<TaskSnapshot> uploadFileFromPath(Reference ref, String path) {
  return uploadFileFromPathImpl(ref, path);
}
