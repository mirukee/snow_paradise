import 'package:flutter/widgets.dart';

import 'platform_file_image_io.dart'
    if (dart.library.html) 'platform_file_image_web.dart';

Widget buildFileImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  return buildFileImageImpl(
    path,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: errorBuilder,
  );
}
