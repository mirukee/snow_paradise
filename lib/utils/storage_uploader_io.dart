import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

Future<TaskSnapshot> uploadFileFromPathImpl(Reference ref, String path) {
  final file = File(path);
  return ref.putFile(file);
}
