import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/product.dart';
import 'detail_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  String _formatPrice(int price) {
    final priceString = price.toString();
    final buffer = StringBuffer('');
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(priceString[i]);
    }
    buffer.write('원');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 여백 (상태바 대체)
            const SizedBox(height: 16),
            
            // 1. 상단 브랜딩 및 검색바 (수정됨)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // [수정 포인트] 로고 이미지 영역
                  // Transform.scale을 사용하여 강제로 1.5배 확대 (여백 잘라내기 효과)
                  Container(
                    width: 140, // 너비를 살짝 줄여서 검색창 공간 확보
                    height: 45,
                    clipBehavior: Clip.hardEdge, // 확대된 이미지가 네모칸 밖으로 나가지 않게 자름
                    decoration: BoxDecoration(
                      // 영역 확인용 (나중에 투명으로 바꾸거나 삭제 가능)
                      color: Colors.transparent, 
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Transform.scale(
                      scale: 1.1, // 1.5배 확대! (글씨가 커집니다)
                      alignment: Alignment.centerLeft, // 왼쪽 기준으로 확대
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain, // 비율 유지하며 안에 맞춤
                        filterQuality: FilterQuality.high, // 고화질 렌더링
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'Snow Paradise',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12), // 간격 조정
                  
                  // 검색바 (남은 공간 전체 사용)
                  Expanded(
                    child: Container(
                      height: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[600], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '브랜드, 모델명, 사이즈 등 검색',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            // 2. 메인 카테고리 (SKI & SNOWBOARD)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // SKI 카드
                  Expanded(
                    child: _buildMainCategoryCard(
                      context,
                      title: 'SKI',
                      imageUrl: 'https://picsum.photos/400/400?random=ski',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // SNOWBOARD 카드
                  Expanded(
                    child: _buildMainCategoryCard(
                      context,
                      title: 'SNOWBOARD',
                      imageUrl: 'https://picsum.photos/400/400?random=snowboard',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 3. 서브 카테고리 (의류, 시즌권, 시즌방, 강습)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSubCategoryItem(
                    context,
                    icon: Icons.checkroom,
                    label: '의류',
                  ),
                  _buildSubCategoryItem(
                    context,
                    icon: Icons.confirmation_number,
                    label: '시즌권',
                  ),
                  _buildSubCategoryItem(
                    context,
                    icon: Icons.home,
                    label: '시즌방',
                  ),
                  _buildSubCategoryItem(
                    context,
                    icon: Icons.school,
                    label: '강습',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 구분선
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 24),
            // 4. 가로 스크롤 추천 리스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  const Text(
                    '🔥 지금 뜨는 매물',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 가로 스크롤 상품 리스트
                  SizedBox(
                    height: 260,
                    child: dummyProducts.isEmpty
                        ? const Center(
                            child: Text(
                              '상품이 없습니다',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: dummyProducts.length,
                            itemBuilder: (context, index) {
                              if (index >= dummyProducts.length) {
                                return const SizedBox.shrink();
                              }
                              final product = dummyProducts[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index < dummyProducts.length - 1 ? 12 : 0,
                                ),
                                child: _buildPopularProductCard(context, product),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCategoryCard(
    BuildContext context, {
    required String title,
    required String imageUrl,
  }) {
    return GestureDetector(
      onTap: () {
        // 카테고리 클릭 액션 (추후 구현)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title 카테고리 (준비 중)')),
        );
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 배경 이미지
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 50,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
            // 그라데이션 오버레이
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 텍스트 (좌측 하단)
            Positioned(
              bottom: 16,
              left: 16,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryItem(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label (준비 중)')),
        );
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.grey[700],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(product: product),
          ),
        );
      },
      child: Container(
        width: 140,
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상품 이미지 (고정 높이)
            Container(
              width: double.infinity,
              height: 140,
              color: Colors.grey[200],
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 30,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      )
                    : const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 30,
                      ),
              ),
            ),
            // 상품 정보 영역 (나머지 공간)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 브랜드와 상품명
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 브랜드 (maxLines: 1)
                        if (product.brand.isNotEmpty)
                          Text(
                            product.brand,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        // 상품명 (maxLines: 2)
                        if (product.title.isNotEmpty)
                          Text(
                            product.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 가격 (maxLines: 1)
                    Text(
                      _formatPrice(product.price),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}