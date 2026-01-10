import 'package:flutter/material.dart';
import '../models/product.dart';
import '../data/dummy_data.dart'; // 기존 더미 데이터 가져오기

class ProductService extends ChangeNotifier {
  // 전체 상품 리스트 (초기값은 더미 데이터)
  List<Product> _productList = dummyProducts;

  // 찜한 상품 ID 목록
  final Set<String> _likedProductIds = {};

  List<Product> get productList => _productList;

  // 찜한 상품만 가져오는 함수
  List<Product> get likedProducts {
    return _productList.where((product) => _likedProductIds.contains(product.id)).toList();
  }

  // 찜 여부 확인 함수
  bool isLiked(String productId) {
    return _likedProductIds.contains(productId);
  }

  // 찜하기 토글 함수 (누르면 켜지고, 다시 누르면 꺼짐)
  void toggleLike(String productId) {
    if (_likedProductIds.contains(productId)) {
      _likedProductIds.remove(productId);
    } else {
      _likedProductIds.add(productId);
    }
    // "데이터가 바뀌었으니 화면들 다시 그려라!" 라고 방송
    notifyListeners();
  }
}