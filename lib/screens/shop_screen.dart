import 'package:flutter/material.dart';
import 'category_product_screen.dart';
import 'search_screen.dart';

/// 쇼핑 탭 화면
/// 카테고리별 상품 탐색을 위한 메인 쇼핑 화면입니다.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  // 카테고리 데이터 (한글명, 영문명, 이미지 URL)
  // 카테고리 데이터 (한글명, 영문명, 이미지 URL)
  static const List<Map<String, String>> categories = [
    {
      'title': '스키',
      'subtitle': 'Ski',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBPsF_nks7aKO4gNpbnm7UCaROaflspWwjLL4XR30eXvctM1IlbBQeoQ1QAfx_bYWdWD4x7y2lpOd1CVjJo7_nLMoHxOi7whJHC-aIkcESf_BbI-qsgD0_i3c2w7wCfakLjPjexSuvmWEwKRTWBKo-skXLig8KprBMUgouQc77-zDUyuQeaIlvRVlDi6UGBw6KiBCDqif9ksCngur1K-OJBAA-wHjhY82jTJYUVhR6LTVBdvBvXz_QsgaCKMfL0XDKKcqBjFAlNcsHR',
    },
    {
      'title': '스노우보드',
      'subtitle': 'Snowboard',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDv451hQsew0FcrAJQ7sEIFDflzrkx4Do2Gj3C2P0eAzHO4ePPNImiViwvcuTJHGmieBLzgxc-C8mSsudw0TsXEioI4_1ysmWHZ945GrlrYYcruoy7JuCBW7gNxB_VoYJnSsp804mpphZY--rn5IewBXIkSE1PHuFawOecjPUxgiELdkbBKnAIscCwCjL4myOM9eI15ORJc5o-Z4lyzON0M0Vb4beLOoCbgi9gsqdviEeim1x5pQmhetLJP_0CvVKvIfw2QNklEblil',
    },
    {
      'title': '의류',
      'subtitle': 'Apparel',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBVMDNfibME5nL0S47C_pObCWSLDi3wYC4zHL_i7Q-PnMQt5s6s0Sa0jt3MOb4EPjHdSuHE_RJY8QzCHlJhSVCl1KQApCo3KhleHx-jCX0bpKRli1cUP0nm9fmfzAxNWWMGwc9_Gyevyv3qZsaiKbXW6iLg1aRF3afLzU-ZCY56CbebUiu4HXUtnT2PAYv67KkHVrq8cvGDjGZdNVaVxMSqrKBg_iguWQkKMIWyLLLGEaKv-e3ZOhsyVHO4bGroie4F3EXbRLLErgwv',
    },
    {
      'title': '장비/보호대',
      'subtitle': 'Gear & Protection',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDCfM_sgj7vuDNJGSPVWstpIINA3UH0ECpHkNb4Fh6p4EByMa_xwZym-nKLIGuW4qMPsRqG31OJiRH7TpxjoILiU-4W7W13FomjESvgNnTSPL2f2fwMBo50yUkJqhWTpx0dJlEOotopY-dEmv6GuxRnjtd3JldR2QO25r9EUULo6fnJHt40UOzHYRqVpdgYFIX1IdmVri3ny7xBRXVVrjp6y4b0PN-nWXwoobm_oaUpJQvNIYTahBK-BuUqmdbx_CHSjsQZoALWdNnw',
    },
    {
      'title': '시즌권',
      'subtitle': 'Passes',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAL3gr92OZzeu4VVfF1gbPqtt8BySuptUwBS0l-VPiGuF1xqm6lUMw5EpoqsFfDVh33C6E1S1kNq39PsjgfyPiiq7MzxrdNRwjv6_on6jtWua6qmGk6FWYg4FdMzPRSbrIwJ7QJDGn9hTL9Od24RmgSrt-RWfLjZBQUqfSUtNHwH_2JqqujgPeYs8UEjUGoBki2dlE5LYpSvXQL63rtlfM1-ggH-72Rtsz_zt6vb8JqXsZxoMnRVAvHhLHCVmgYfyMuh6KuQsuaofk7',
    },
    {
      'title': '시즌방',
      'subtitle': 'Season Rental',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBPsF_nks7aKO4gNpbnm7UCaROaflspWwjLL4XR30eXvctM1IlbBQeoQ1QAfx_bYWdWD4x7y2lpOd1CVjJo7_nLMoHxOi7whJHC-aIkcESf_BbI-qsgD0_i3c2w7wCfakLjPjexSuvmWEwKRTWBKo-skXLig8KprBMUgouQc77-zDUyuQeaIlvRVlDi6UGBw6KiBCDqif9ksCngur1K-OJBAA-wHjhY82jTJYUVhR6LTVBdvBvXz_QsgaCKMfL0XDKKcqBjFAlNcsHR',
    },
    {
      'title': '강습',
      'subtitle': 'Lesson',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDv451hQsew0FcrAJQ7sEIFDflzrkx4Do2Gj3C2P0eAzHO4ePPNImiViwvcuTJHGmieBLzgxc-C8mSsudw0TsXEioI4_1ysmWHZ945GrlrYYcruoy7JuCBW7gNxB_VoYJnSsp804mpphZY--rn5IewBXIkSE1PHuFawOecjPUxgiELdkbBKnAIscCwCjL4myOM9eI15ORJc5o-Z4lyzON0M0Vb4beLOoCbgi9gsqdviEeim1x5pQmhetLJP_0CvVKvIfw2QNklEblil',
    },
    {
      'title': '기타',
      'subtitle': 'Others',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDsQBuaizYIIEvsr6hSQ2Cy3lbbTxzPKyyHuvfnoW_ha_m6wPVpZGBg0Xnl8E-FjbsRbd0Vog0O8TDecL8MTWt_FWfAx4w6eMS7rwJA9I022XH10CyJSIM_IUvGOlZzSF-bWfA3K3K_I_BQB8bkJoZIvT9lR5_V5wzlS-aU0-TsE3dvLcNOv45DVwUAHpWdM_gHOssZA2oP-AWtp5iY-vDluXy_lv9ZwxtN1WYUqpqDqv-bZckY5FRDtOdWe_PzfTgpH7gpoNllz8Jo',
    },
  ];

  // Ice Blue 테마 색상
  static const Color iceBlueLight = Color(0xFFF0F8FF);
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF111518);
  static const Color textGrey = Color(0xFF637688);
  static const Color searchBackground = Color(0xFFF0F2F4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더: 타이틀
            _buildHeader(),
            // 검색 바
            _buildSearchBar(context),
            // 카테고리 그리드
            Expanded(
              child: _buildCategoryGrid(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 영역 - "쇼핑" 타이틀
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Text(
        '쇼핑',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textDark,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  /// 검색 바 - 탭 시 SearchScreen으로 이동
  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () {
          // SearchScreen으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: searchBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.search,
                color: primaryBlue,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '찾으시는 장비가 있나요?',
                  style: TextStyle(
                    fontSize: 15,
                    color: textGrey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 카테고리 그리드 - 2열 레이아웃
  Widget _buildCategoryGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.95, // 세로 길이를 줄여서 한 화면에 더 많이 보이게 조정
      ),
      itemBuilder: (context, index) {
        return _buildCategoryCard(context, categories[index]);
      },
    );
  }

  /// 카테고리 카드 UI
  Widget _buildCategoryCard(BuildContext context, Map<String, String> category) {
    final title = category['title']!;
    final subtitle = category['subtitle']!;
    final imageUrl = category['image']!;

    return GestureDetector(
      onTap: () {
        // 카테고리별 상품 목록 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductScreen(category: title),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: iceBlueLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리 텍스트 (한글 + 영문)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textGrey,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // 우하단 원형 이미지 컨테이너
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        spreadRadius: -2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      // 이미지 로딩 중 표시
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: primaryBlue,
                          ),
                        );
                      },
                      // 이미지 로드 실패 시 아이콘 표시
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(
                            _getCategoryIcon(title),
                            size: 32,
                            color: primaryBlue,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 카테고리별 기본 아이콘 (이미지 로드 실패 시 대체)
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '스키':
        return Icons.downhill_skiing;
      case '스노우보드':
        return Icons.snowboarding;
      case '의류':
        return Icons.checkroom;
      case '보호대/헬멧':
        return Icons.shield;
      case '시즌권':
        return Icons.confirmation_number;
      case '기타':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }
}
