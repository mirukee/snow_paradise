import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'platform_file_image.dart';

Widget buildLocalImageFromPath(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  double errorIconSize = 24,
  Widget? loadingWidget,
}) {
  final errorWidget = _buildErrorIcon(errorIconSize);
  final errorBuilder = (BuildContext context, Object error, StackTrace? stackTrace) {
    return errorWidget;
  };

  if (kIsWeb) {
    return Image.network(
      path,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return loadingWidget ??
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
      },
    );
  }

  return buildFileImage(
    path,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: errorBuilder,
  );
}

Widget buildProductImage(
  Product product, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  double errorIconSize = 30,
  Widget? loadingWidget,
}) {
  final localPath = product.localImagePath;
  if (localPath != null && localPath.isNotEmpty) {
    return buildLocalImageFromPath(
      localPath,
      fit: fit,
      width: width,
      height: height,
      errorIconSize: errorIconSize,
      loadingWidget: loadingWidget,
    );
  }

  if (product.imageUrl.isEmpty) {
    return _buildErrorIcon(errorIconSize);
  }

  final errorWidget = _buildErrorIcon(errorIconSize);
  return Image.network(
    product.imageUrl,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) => errorWidget,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return loadingWidget ??
          const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
    },
  );
}

Widget _buildErrorIcon(double size) {
  return Center(
    child: Icon(
      Icons.image_not_supported,
      color: Colors.grey,
      size: size,
    ),
  );
}
