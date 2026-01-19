import 'package:flutter/material.dart';
import '../constants/categories.dart';

/// 동적 속성 입력 폼 위젯
/// 카테고리/서브카테고리에 따라 필요한 속성 필드를 렌더링합니다.
/// [isFilterMode]가 true일 경우 다중 선택(List) 및 범위 입력(Range) UI를 제공합니다.
class DynamicAttributeForm extends StatefulWidget {
  final String category;
  final String? subCategory;
  final Map<String, dynamic> selectedSpecs; // String OR List<String> OR Map<String, String>(Range)
  final Function(String key, dynamic value) onSpecChanged;
  final bool isFilterMode;

  const DynamicAttributeForm({
    super.key,
    required this.category,
    required this.subCategory,
    required this.selectedSpecs,
    required this.onSpecChanged,
    this.isFilterMode = false,
  });

  @override
  State<DynamicAttributeForm> createState() => _DynamicAttributeFormState();
}

class _DynamicAttributeFormState extends State<DynamicAttributeForm> {
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF111518);
  static const Color textGrey = Color(0xFF637688);

  // 텍스트 필드 컨트롤러 관리 (단일 입력용)
  final Map<String, TextEditingController> _textControllers = {};
  
  // 범위 입력용 컨트롤러 (Min, Max)
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};

  @override
  void didUpdateWidget(DynamicAttributeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부 변경 사항 반영 로직 (필요 시 구현)
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) controller.dispose();
    for (final controller in _minControllers.values) controller.dispose();
    for (final controller in _maxControllers.values) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subCategory == null) return const SizedBox.shrink();

    // Key format: "Category/SubCategory"
    final key = '${widget.category}/${widget.subCategory}';
    final requiredAttrs = CategoryAttributes.requiredAttributes[key];

    if (requiredAttrs == null || requiredAttrs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: requiredAttrs.map((attrKey) {
        final def = CategoryAttributes.definitions[attrKey];
        if (def == null) return const SizedBox.shrink();

        return Column(
          children: [
            _buildInputField(attrKey, def),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildInputField(String key, AttributeDefinition def) {
    switch (def.inputType) {
      case AttributeInputType.text:
        return widget.isFilterMode 
            ? _buildRangeInput(key, def) 
            : _buildTextInput(key, def);
      case AttributeInputType.searchSelect:
        return _buildSearchableSelector(key, def);
      default:
        return _buildChipSelector(key, def);
    }
  }

  /// 1. 칩 선택기 (Chip)
  Widget _buildChipSelector(String key, AttributeDefinition def) {
    final selectedValue = widget.selectedSpecs[key];
    
    // 다중 선택 여부 확인
    final List<String> selectedList = widget.isFilterMode && selectedValue is List
        ? List<String>.from(selectedValue)
        : (selectedValue is String ? [selectedValue] : []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          def.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: def.options.map((option) {
            final isSelected = selectedList.contains(option);
            return GestureDetector(
              onTap: () {
                if (widget.isFilterMode) {
                  // 다중 선택 모드
                  final newList = List<String>.from(selectedList);
                  if (isSelected) {
                    newList.remove(option);
                  } else {
                    newList.add(option);
                  }
                  widget.onSpecChanged(key, newList);
                } else {
                  // 단일 선택 모드
                  widget.onSpecChanged(key, isSelected ? null : option);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 2. 텍스트 입력 (Text) - 단일
  Widget _buildTextInput(String key, AttributeDefinition def) {
    if (!_textControllers.containsKey(key)) {
      _textControllers[key] = TextEditingController(text: widget.selectedSpecs[key]?.toString());
    }
    
    // 외부 값 동기화 (입력 중이 아닐 때)
    final val = widget.selectedSpecs[key]?.toString() ?? '';
    if (val != _textControllers[key]!.text) {
         _textControllers[key]!.text = val;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          def.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textControllers[key],
          keyboardType: TextInputType.number,
          onChanged: (value) => widget.onSpecChanged(key, value),
          decoration: InputDecoration(
            hintText: '${def.label} 입력 (예: 153)',
            hintStyle: const TextStyle(color: textGrey, fontSize: 14),
            suffixText: key.contains('length') ? 'cm' : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue),
            ),
          ),
        ),
      ],
    );
  }

  /// 2-1. 범위 입력 (Range) - 필터 모드 전용
  Widget _buildRangeInput(String key, AttributeDefinition def) {
    if (!_minControllers.containsKey(key)) _minControllers[key] = TextEditingController();
    if (!_maxControllers.containsKey(key)) _maxControllers[key] = TextEditingController();

    // 값 복원 (Map 형태: {'min': '150', 'max': '160'})
    final rangeMap = widget.selectedSpecs[key] is Map ? widget.selectedSpecs[key] as Map : {};
    if (rangeMap['min'] != _minControllers[key]!.text) _minControllers[key]!.text = rangeMap['min'] ?? '';
    if (rangeMap['max'] != _maxControllers[key]!.text) _maxControllers[key]!.text = rangeMap['max'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${def.label} 범위',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minControllers[key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '최소',
                  suffixText: 'cm',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                onChanged: (val) => _updateRange(key),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('~', style: TextStyle(color: textGrey)),
            ),
            Expanded(
              child: TextField(
                controller: _maxControllers[key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '최대',
                  suffixText: 'cm',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                onChanged: (val) => _updateRange(key),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updateRange(String key) {
    final min = _minControllers[key]!.text;
    final max = _maxControllers[key]!.text;
    if (min.isEmpty && max.isEmpty) {
      widget.onSpecChanged(key, null);
    } else {
      widget.onSpecChanged(key, {'min': min, 'max': max});
    }
  }

  /// 3. 검색 가능한 선택기 (바텀시트)
  Widget _buildSearchableSelector(String key, AttributeDefinition def) {
    final selectedValue = widget.selectedSpecs[key];
    
    String displayText = '선택해주세요';
    if (selectedValue != null) {
      if (widget.isFilterMode && selectedValue is List) {
        final list = selectedValue;
        displayText = list.isEmpty ? '선택해주세요' : '${list.length}개 선택됨';
        if (list.length == 1) displayText = list.first.toString();
      } else {
        displayText = selectedValue.toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          def.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showSearchModal(key, def),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (selectedValue != null && (selectedValue is! List || selectedValue.isNotEmpty)) 
                    ? primaryBlue 
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayText,
                  style: TextStyle(
                    color: (selectedValue != null && (selectedValue is! List || selectedValue.isNotEmpty)) 
                        ? textDark 
                        : textGrey,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: textGrey),
              ],
            ),
          ),
        ),
        // 다중 선택 시 선택된 항목 태그 표시 (필터 모드일 때)
        if (widget.isFilterMode && selectedValue is List && selectedValue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedValue.map((e) => Chip(
                label: Text(e.toString(), style: const TextStyle(fontSize: 12)),
                backgroundColor: primaryBlue.withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: primaryBlue),
                deleteIcon: const Icon(Icons.close, size: 14, color: primaryBlue),
                onDeleted: () {
                   final newList = List<String>.from(selectedValue);
                   newList.remove(e);
                   widget.onSpecChanged(key, newList);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              )).toList(),
            ),
          ),
      ],
    );
  }

  /// 검색 모달 표시
  void _showSearchModal(String key, AttributeDefinition def) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchSelectionModal(
          title: def.label,
          options: def.options,
          isMultiSelect: widget.isFilterMode,
          selectedValues: widget.isFilterMode && widget.selectedSpecs[key] is List
              ? List<String>.from(widget.selectedSpecs[key])
              : (widget.selectedSpecs[key] != null ? [widget.selectedSpecs[key].toString()] : []),
          onConfirmed: (values) {
            if (widget.isFilterMode) {
              widget.onSpecChanged(key, values);
            } else {
              widget.onSpecChanged(key, values.isNotEmpty ? values.first : null);
            }
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

/// 검색 선택 모달 (다중 선택 지원)
class _SearchSelectionModal extends StatefulWidget {
  final String title;
  final List<String> options;
  final bool isMultiSelect;
  final List<String> selectedValues;
  final Function(List<String>) onConfirmed;

  const _SearchSelectionModal({
    required this.title,
    required this.options,
    this.isMultiSelect = false,
    required this.selectedValues,
    required this.onConfirmed,
  });

  @override
  State<_SearchSelectionModal> createState() => _SearchSelectionModalState();
}

class _SearchSelectionModalState extends State<_SearchSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredOptions = [];
  late List<String> _tempSelectedValues;

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _tempSelectedValues = List.from(widget.selectedValues);
    
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredOptions = widget.options.where((option) {
          return option.toLowerCase().contains(query);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String value) {
    setState(() {
      if (widget.isMultiSelect) {
        if (_tempSelectedValues.contains(value)) {
          _tempSelectedValues.remove(value);
        } else {
          _tempSelectedValues.add(value);
        }
      } else {
        _tempSelectedValues = [value];
        // 단일 선택은 선택 즉시 적용 및 닫기
        widget.onConfirmed(_tempSelectedValues);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.title} 선택',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111518),
                  ),
                ),
                if (widget.isMultiSelect)
                  GestureDetector(
                    onTap: () => widget.onConfirmed(_tempSelectedValues),
                    child: const Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E97EA),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 검색창
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '${widget.title} 검색',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF637688)),
                filled: true,
                fillColor: const Color(0xFFF6F7F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          // 리스트
          Expanded(
            child: ListView.builder(
              itemCount: _filteredOptions.length + (_searchController.text.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                 // 직접 입력 옵션
                if (_searchController.text.isNotEmpty && index == 0) {
                     final searchValue = _searchController.text;
                     if (_filteredOptions.contains(searchValue)) {
                       return const SizedBox.shrink(); 
                     }
                     return ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Color(0xFF3E97EA)),
                      title: Text(
                        '"$searchValue" 직접 입력',
                        style: const TextStyle(
                          color: Color(0xFF3E97EA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _toggleSelection(searchValue),
                    );
                }
                
                final realIndex = _searchController.text.isNotEmpty ? index - 1 : index;
                if (realIndex < 0) return const SizedBox.shrink();

                final option = _filteredOptions[realIndex];
                final isSelected = _tempSelectedValues.contains(option);

                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF3E97EA) : const Color(0xFF111518),
                    ),
                  ),
                  trailing: isSelected 
                      ? const Icon(Icons.check, color: Color(0xFF3E97EA)) 
                      : null,
                  onTap: () => _toggleSelection(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
