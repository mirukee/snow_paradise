import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/main_tab_provider.dart';
import '../providers/user_service.dart';
import '../services/user_service.dart' as profile_service;
import '../widgets/product_image.dart';
import '../widgets/dynamic_attribute_form.dart';
import 'package:flutter/foundation.dart';
import '../utils/image_compressor.dart';
import '../constants/categories.dart';

/// 상품 등록 화면
/// Stitch 디자인 기반 - 카테고리별 동적 필드, 선택형 칩 버튼
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);
  static const Color dividerColor = Color(0xFFF0F2F4);
  static const Color surfaceColor = Color(0xFFF8FAFC);

  // 컨트롤러
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isUploading = false;
  bool _acceptPriceOffer = true;

  // 이미지 선택
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];

  // 카테고리 선택
  String _selectedCategory = '스키';
  List<String> get _categories => CategoryConstants.subCategories.keys.toList();

  // 카테고리별 필드 값
  String? _selectedSubCategory;
  String? _selectedCondition;
  
  // 동적 속성 저장 (Key: Attribute Key, Value: Selected Option)
  // 동적 속성 저장 (Key: Attribute Key, Value: Selected Option)
  final Map<String, dynamic> _selectedSpecs = {};

  // 상품 상태 옵션
  final List<Map<String, String>> _conditions = [
    {'emoji': '🏷️', 'label': '새상품', 'desc': '(미개봉)'},
    {'emoji': '⭐', 'label': 'S급', 'desc': '(미사용)'},
    {'emoji': '😀', 'label': 'A급', 'desc': '(사용감 적음)'},
    {'emoji': '😐', 'label': 'B급', 'desc': '(사용감 있음)'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _formatPrice(String value) {
    if (value.isEmpty) return;
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.isEmpty) return;

    final number = int.parse(value);
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    _priceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 10장까지 선택할 수 있어요.')),
      );
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        // Web에서는 maxWidth 등이 무시될 수 있음 -> ImageCompressor 사용
      );
      if (picked == null) return;
      
      // 이미지 선택 즉시 압축 및 JPEG 변환 (HEIC 대응)
      final compressedBytes = await ImageCompressor.compressImage(picked);
      if (compressedBytes != null) {
        final jpegFile = XFile.fromData(
          compressedBytes, 
          name: '${picked.name}.jpg',
          mimeType: 'image/jpeg',
        );
        
        if (!mounted) return;
        setState(() {
          _selectedImages.add(jpegFile);
        });
      } else {
        if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지원하지 않는 이미지 형식이거나 불러올 수 없습니다.')),
        );
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요. 권한을 확인해주세요.')),
      );
    }
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      // 카테고리 변경 시 하위 선택 초기화
      _selectedSubCategory = null;
      _selectedSpecs.clear();
      _selectedCondition = null;
    });
  }

  Future<void> _submitProduct() async {
    final title = _titleController.text.trim();
    final priceText = _priceController.text.replaceAll(',', '').trim();
    final description = _descController.text.trim();

    if (title.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 가격을 입력해주세요.')),
      );
      return;
    }

    final price = int.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가격을 올바르게 입력해주세요.')),
      );
      return;
    }

    final currentUser = context.read<UserService>().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      String sellerName = currentUser.displayName ?? currentUser.email ?? '익명';
      String sellerProfile = '';
      try {
        final profileUser = await profile_service.UserService().getUser(currentUser.uid);
        final nickname = profileUser?.nickname.trim() ?? '';
        if (nickname.isNotEmpty) sellerName = nickname;
        sellerProfile = profileUser?.profileImageUrl?.trim() ?? '';
      } catch (_) {}

      final productId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      // 모든 선택된 이미지 경로 리스트 생성
      final localImagePaths = _selectedImages.map((img) => img.path).toList();

      // 순수 설명만 저장 (스펙 정보는 별도 필드에 저장됨)

      // Specs에서 주요 필드 추출 (검색/호환성용)
      String brand = _selectedCategory;
      String size = 'Free';

      // 브랜드 추출
      for (final entry in _selectedSpecs.entries) {
        if (entry.key.contains('brand')) {
          brand = entry.value;
          break;
        }
      }

      // 사이즈/길이 추출
      for (final entry in _selectedSpecs.entries) {
        if (entry.key.contains('length') || entry.key.contains('size')) {
          size = entry.value;
          break;
        }
      }

      final year = _selectedSpecs[CategoryAttributes.ATTR_YEAR] ?? '${now.year}년';

      final product = Product(
        id: productId,
        createdAt: now,
        title: title,
        price: price,
        brand: brand,
        category: _selectedCategory,
        subCategory: _selectedSubCategory ?? '',
        specs: Map<String, String>.from(_selectedSpecs), // 스펙 맵 저장
        condition: _selectedCondition ?? '중고',
        localImagePaths: localImagePaths,
        description: description,
        size: size,
        year: year,
        sellerName: sellerName,
        sellerProfile: sellerProfile,
        sellerId: currentUser.uid,
      );

      await context.read<ProductService>().addProduct(product, images: _selectedImages);

      if (!mounted) return;
      _clearForm();

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.read<MainTabProvider>().setIndex(0);
      }
      messenger.showSnackBar(const SnackBar(content: Text('등록 완료!')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('업로드에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _priceController.clear();
    _descController.clear();
    setState(() {
      _selectedImages.clear();
      _selectedSubCategory = null;
      _selectedSpecs.clear();
      _selectedCondition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(),
            // 폼 컨텐츠
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지 업로드 섹션
                    _buildImageSection(),
                    _buildThickDivider(),
                    // 카테고리 선택
                    _buildCategorySection(),
                    _buildThinDivider(),
                    // 카테고리별 상세 옵션
                    _buildCategorySpecificFields(),
                    _buildThickDivider(),
                    // 상품 상태
                    _buildConditionSection(),
                    _buildThickDivider(),
                    // 기본 정보 입력
                    _buildBasicInfoSection(),
                    _buildThickDivider(),
                    // 설명 입력
                    _buildDescriptionSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Expanded(
            child: Text(
              '내 물건 팔기',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
          TextButton(
            onPressed: _isUploading ? null : _submitProduct,
            child: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '완료',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewImage(XFile file, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, error, stackTrace) {
              // Web에서 렌더링 실패 시 (특히 HEIC)
              if (kIsWeb) {
                return Container(
                  width: width,
                  height: height,
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                       Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                       SizedBox(height: 4),
                       Text('미리보기 불가\n(모바일 확인)', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                );
              }
              return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
            },
          );
        }
        return Container(
          width: width ?? 80, // 기본값
          height: height ?? 80,
          color: Colors.grey[100],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  /// 이미지 업로드 섹션
  Widget _buildImageSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 카메라 버튼
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: textGrey, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedImages.length}/10',
                          style: const TextStyle(
                            fontSize: 12,
                            color: textGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 선택된 이미지들
                ...List.generate(_selectedImages.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: _buildPreviewImage(
                              _selectedImages[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // 대표 배지
                        if (index == 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(15),
                                ),
                              ),
                              child: const Text(
                                '대표',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        // 삭제 버튼
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedImages.removeAt(index));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '* 상품 이미지는 최대 10장까지 등록 가능합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  /// 카테고리 선택 섹션
  Widget _buildCategorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카테고리',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _onCategoryChanged(category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue : surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected ? primaryBlue : Colors.grey[200]!,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : textGrey,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 카테고리별 상세 필드 (동적 생성)
  Widget _buildCategorySpecificFields() {
    final subCategories = CategoryConstants.getSubCategories(_selectedCategory);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 소분류 (종류) - 공통
          if (subCategories.isNotEmpty)
            _buildChipSelector(
              label: '종류',
              options: subCategories,
              selectedValue: _selectedSubCategory,
              onSelected: (value) {
                setState(() {
                  _selectedSubCategory = value;
                  _selectedSpecs.clear(); // 소분류 변경 시 스펙 초기화
                });
              },
            ),

          if (subCategories.isNotEmpty) const SizedBox(height: 16),

          // 2. 소분류별 동적 속성 필드
          if (_selectedSubCategory != null)
            DynamicAttributeForm(
              category: _selectedCategory,
              subCategory: _selectedSubCategory,
              selectedSpecs: _selectedSpecs,
              onSpecChanged: (key, value) {
                setState(() {
                  // 등록 모드에서는 단일 값만 사용하므로 Map이나 List가 오면 처리
                  if (value is List) {
                     // 혹시 리스트가 오면 첫번째 값 사용하거나 무시
                     _selectedSpecs[key] = value.isNotEmpty ? value.first.toString() : null;
                  } else if (value is Map) {
                     // 범위 값이 오면 무시 (등록시엔 사용 안함)
                     // or 필요한 로직
                  } else {
                     _selectedSpecs[key] = value;
                  }
                  
                  // null이면 제거
                  if (value == null) {
                    _selectedSpecs.remove(key);
                  }
                });
              },
            ),
        ],
      ),
    );
  }





  /// 칩 선택기
  Widget _buildChipSelector({
    required String label,
    required List<String> options,
    required String? selectedValue,
    required Function(String) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((option) {
              final isSelected = selectedValue == option;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? primaryBlue : Colors.grey[200]!,
                      ),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : textGrey,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }



  /// 상품 상태 섹션
  Widget _buildConditionSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상품 상태',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _conditions.map((condition) {
                final label = '${condition['label']}${condition['desc']}';
                final isSelected = _selectedCondition == condition['label'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCondition = condition['label']);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected ? primaryBlue : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(condition['emoji']!),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? primaryBlue : textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 기본 정보 입력 섹션
  Widget _buildBasicInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 제목
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: '글 제목을 입력해주세요',
              hintStyle: TextStyle(color: textGrey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            style: const TextStyle(fontSize: 18, color: textDark),
          ),
          Divider(color: dividerColor, height: 1),
          // 가격
          Row(
            children: [
              const Text(
                '₩',
                style: TextStyle(fontSize: 18, color: textGrey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  onChanged: _formatPrice,
                  decoration: const InputDecoration(
                    hintText: '가격 입력',
                    hintStyle: TextStyle(color: textGrey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: dividerColor, height: 1),
          // 가격 제안받기 토글
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      '가격 제안받기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.help_outline, size: 16, color: Colors.grey[400]),
                  ],
                ),
                Switch(
                  value: _acceptPriceOffer,
                  onChanged: (value) => setState(() => _acceptPriceOffer = value),
                  activeTrackColor: primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 설명 입력 섹션
  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _descController,
        maxLines: 8,
        decoration: const InputDecoration(
          hintText: '구매 시기, 브랜드, 모델명, 사용 기간, 하자 여부 등 상품 설명을 최대한 자세히 적어주세요.\n\n(판매 금지 물품은 게시가 제한될 수 있습니다.)',
          hintStyle: TextStyle(color: textGrey, height: 1.5),
          border: InputBorder.none,
        ),
        style: const TextStyle(fontSize: 16, color: textDark, height: 1.5),
      ),
    );
  }

  /// 두꺼운 구분선
  Widget _buildThickDivider() {
    return Container(height: 8, color: dividerColor);
  }

  /// 얇은 구분선
  Widget _buildThinDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: dividerColor, height: 1),
    );
  }
}
