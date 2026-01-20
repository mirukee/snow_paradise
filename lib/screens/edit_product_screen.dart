import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';

import '../widgets/dynamic_attribute_form.dart';
import '../constants/categories.dart';

/// 상품 수정 화면
/// Stitch 디자인 기반 - 카테고리별 동적 필드, 선택형 칩 버튼
class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);
  static const Color dividerColor = Color(0xFFF0F2F4);
  static const Color surfaceColor = Color(0xFFF8FAFC);

  // 컨트롤러
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;
  bool _isSaving = false;

  // 카테고리 선택
  String _selectedCategory = '기타';
  final List<String> _categories = ['스노우보드', '스키', '의류', '보호장비', '시즌권', '기타'];

  // 카테고리별 필드 값
  String? _selectedSubCategory;
  String? _selectedCondition;
  String? _selectedTradeLocationKey;

  // 동적 속성 저장
  // 동적 속성 저장
  final Map<String, dynamic> _selectedSpecs = {};

  // 상품 상태 옵션
  final List<Map<String, String>> _conditions = [
    {'emoji': '🏷️', 'label': '새상품', 'desc': '(미개봉)'},
    {'emoji': '⭐', 'label': 'S급', 'desc': '(미사용)'},
    {'emoji': '😀', 'label': 'A급', 'desc': '(사용감 적음)'},
    {'emoji': '😐', 'label': 'B급', 'desc': '(사용감 있음)'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _priceController = TextEditingController(text: _formatNumber(widget.product.price));
    
    // 기존 description에서 스펙 정보 제거하고 순수 설명만 추출
    _descController = TextEditingController(text: _extractPureDescription(widget.product.description));
    
    // 기존 카테고리 설정
    if (_categories.contains(widget.product.category)) {
      _selectedCategory = widget.product.category;
    }
    
    // 기존 서브카테고리 설정
    if (widget.product.subCategory.isNotEmpty) {
      _selectedSubCategory = widget.product.subCategory;
    }

    // 기존 스펙 설정
    if (widget.product.specs.isNotEmpty) {
      _selectedSpecs.addAll(widget.product.specs);
    }
    
    // 기존 상태 설정
    final existingCondition = widget.product.condition;
    if (_conditions.any((c) => c['label'] == existingCondition)) {
      _selectedCondition = existingCondition;
    }

    if (widget.product.tradeLocationKey.isNotEmpty) {
      _selectedTradeLocationKey = widget.product.tradeLocationKey;
    }
  }

  /// description에서 스펙 라인(종류:, 길이:, 쉐입:, 브랜드:, 상태:)을 제거하고 순수 설명만 반환
  String _extractPureDescription(String description) {
    final lines = description.split('\n');
    final pureLines = <String>[];
    bool skipEmptyLines = true;
    
    for (final line in lines) {
      final trimmed = line.trim();
      // 스펙 정보 라인인지 확인
      if (trimmed.startsWith('종류:') ||
          trimmed.startsWith('길이:') ||
          trimmed.startsWith('쉐입:') ||
          trimmed.startsWith('브랜드:') ||
          trimmed.startsWith('상태:')) {
        continue; // 스펙 라인은 건너뛰기
      }
      
      // 빈 줄 처리 - 스펙 라인 다음의 빈 줄도 건너뛰기
      if (trimmed.isEmpty && skipEmptyLines) {
        continue;
      }
      
      skipEmptyLines = false;
      pureLines.add(line);
    }
    
    return pureLines.join('\n').trim();
  }


  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatNumber(int value) {
    final valueString = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < valueString.length; i++) {
      if (i > 0 && (valueString.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(valueString[i]);
    }
    return buffer.toString();
  }

  void _formatPrice(String value) {
    if (value.isEmpty) return;
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.isEmpty) return;

    final number = int.parse(value);
    final formatted = _formatNumber(number);
    _priceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      // 카테고리 변경 시 하위 선택 초기화
      _selectedSubCategory = null;
      _selectedSpecs.clear();
    });
  }

  Future<void> _save() async {
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

    setState(() => _isSaving = true);

    try {
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

      final year = _selectedSpecs[CategoryAttributes.ATTR_YEAR] ?? widget.product.year;

      final updatedProduct = Product(
        id: widget.product.id,
        docId: widget.product.docId,
        createdAt: widget.product.createdAt,
        title: title,
        price: price,
        brand: brand,
        category: _selectedCategory,
        subCategory: _selectedSubCategory ?? '',
        specs: Map<String, String>.from(_selectedSpecs),
        condition: _selectedCondition ?? widget.product.condition,
        imageUrl: widget.product.imageUrl,
        localImagePaths: widget.product.localImagePaths, // 원래 필드명 확인 (localImagePath or localImagePaths?)
        description: description,
        size: size,
        year: year,
        sellerName: widget.product.sellerName,
        sellerProfile: widget.product.sellerProfile,
        sellerId: widget.product.sellerId,
        status: widget.product.status,
        tradeLocationKey: _selectedTradeLocationKey ?? '',
      );

      await context.read<ProductService>().updateProduct(updatedProduct);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                    // 카테고리 선택
                    _buildCategorySection(),
                    _buildThinDivider(),
                    // 카테고리별 상세 옵션
                    _buildCategorySpecificFields(),
                    _buildThickDivider(),
                    // 거래 희망 장소
                    _buildTradeLocationSection(),
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: textDark, size: 22),
          ),
          const Expanded(
            child: Text(
              '상품 수정',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '저장',
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

  /// 카테고리별 상세 필드
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

          // 2. 동적 속성 폼
          DynamicAttributeForm(
            category: _selectedCategory,
            subCategory: _selectedSubCategory,
            selectedSpecs: _selectedSpecs,
            onSpecChanged: (key, value) {
              setState(() {
                if (value == null) {
                  _selectedSpecs.remove(key);
                } else if (value is List) {
                  _selectedSpecs[key] = value.isNotEmpty ? value.first.toString() : null;
                } else {
                  _selectedSpecs[key] = value;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTradeLocationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '거래 희망 장소',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '도시 또는 리조트 중 1개를 선택해주세요.',
            style: TextStyle(
              fontSize: 12,
              color: textGrey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '도시',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
          const SizedBox(height: 10),
          _buildLocationChips(
            options: TradeLocationConstants.cities,
            prefix: 'city',
          ),
          const SizedBox(height: 16),
          const Text(
            '리조트',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
          const SizedBox(height: 10),
          _buildLocationChips(
            options: TradeLocationConstants.resorts,
            prefix: 'resort',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationChips({
    required List<String> options,
    required String prefix,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final key = '$prefix:${option.trim()}';
        final isSelected = _selectedTradeLocationKey == key;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTradeLocationKey = isSelected ? null : key;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryBlue : Colors.grey[300]!,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                color: isSelected ? Colors.white : textGrey,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
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
          hintText: '구매 시기, 브랜드, 모델명, 사용 기간, 하자 여부 등 상품 설명을 최대한 자세히 적어주세요.',
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
