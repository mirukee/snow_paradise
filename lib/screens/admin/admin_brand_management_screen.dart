import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/categories.dart';
import '../../services/brand_service.dart';

/// 관리자 브랜드 관리 화면
class AdminBrandManagementScreen extends StatefulWidget {
  const AdminBrandManagementScreen({super.key});

  @override
  State<AdminBrandManagementScreen> createState() => _AdminBrandManagementScreenState();
}

class _AdminBrandManagementScreenState extends State<AdminBrandManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // 카테고리별 브랜드 목록 (로컬 상태)
  List<String> _skiBrands = [];
  List<String> _boardBrands = [];
  List<String> _apparelBrands = [];
  List<String> _gearBrands = [];

  final TextEditingController _addController = TextEditingController();

  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF101922);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentBrands();
  }

  /// 현재 메모리(CategoryAttributes)에 있는 브랜드 목록 로드
  void _loadCurrentBrands() {
    setState(() {
      _skiBrands = List.from(CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_SKI]?.options ?? []);
      _boardBrands = List.from(CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_BOARD]?.options ?? []);
      _apparelBrands = List.from(CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_APPAREL]?.options ?? []);
      _gearBrands = List.from(CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_GEAR]?.options ?? []);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addController.dispose();
    super.dispose();
  }

  /// Firestore에 저장
  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final brandService = context.read<BrandService>();
      await brandService.updateBrands(
        ski: _skiBrands,
        board: _boardBrands,
        apparel: _apparelBrands,
        gear: _gearBrands,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('브랜드 목록이 저장되었습니다.'),
          backgroundColor: primaryBlue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류 발생: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 브랜드 추가
  void _addBrand(List<String> list) {
    if (_addController.text.trim().isEmpty) return;
    
    final newBrand = _addController.text.trim();
    if (list.contains(newBrand)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 존재하는 브랜드입니다.')),
      );
      return;
    }

    setState(() {
      // '기타'는 항상 마지막에 유지
      if (list.contains('기타')) {
        list.insert(list.length - 1, newBrand);
      } else {
        list.add(newBrand);
      }
    });
    _addController.clear();
    Navigator.pop(context); // 다이얼로그 닫기
  }

  /// 브랜드 추가 다이얼로그 표시
  void _showAddDialog(List<String> list, String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$categoryName 브랜드 추가'),
        content: TextField(
          controller: _addController,
          decoration: const InputDecoration(
            hintText: '브랜드 입력',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _addBrand(list),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _addBrand(list),
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text('추가', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 브랜드 수정
  void _editBrand(List<String> list, int index, String newName) {
    if (newName.trim().isEmpty) return;
    if (list.contains(newName) && list[index] != newName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 존재하는 브랜드입니다.')),
      );
      return;
    }

    setState(() {
      list[index] = newName;
    });
    Navigator.pop(context);
  }

  /// 브랜드 수정 다이얼로그 표시
  void _showEditDialog(List<String> list, int index, String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('브랜드 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _editBrand(list, index, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _editBrand(list, index, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text('수정', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 브랜드 삭제
  void _deleteBrand(List<String> list, String brand) {
    if (brand == '기타') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("'기타' 항목은 삭제할 수 없습니다.")),
      );
      return;
    }
    setState(() {
      list.remove(brand);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('브랜드 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveChanges,
            icon: _isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save, color: primaryBlue),
            label: Text(
              _isLoading ? '저장 중...' : '저장하기',
              style: TextStyle(
                color: _isLoading ? Colors.grey : primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryBlue,
          tabs: const [
            Tab(text: '스키'),
            Tab(text: '보드'),
            Tab(text: '의류'),
            Tab(text: '장비'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBrandList(_skiBrands, '스키'),
          _buildBrandList(_boardBrands, '보드'),
          _buildBrandList(_apparelBrands, '의류'),
          _buildBrandList(_gearBrands, '장비'),
        ],
      ),
    );
  }

  Widget _buildBrandList(List<String> brands, String categoryName) {
    return Column(
      children: [
        // 안내 문구
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Text(
            '💡 팁: 변경 사항을 반영하려면 우측 상단 "저장하기"를 꼭 눌러주세요.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: brands.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = brands.removeAt(oldIndex);
                brands.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final brand = brands[index];
              return ListTile(
                key: ValueKey(brand),
                title: Text(brand),
                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showEditDialog(brands, index, brand),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteBrand(brands, brand),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
      // FAB 위치를 탭 뷰 안으로
    ).applyFloatingActionButton(
      FloatingActionButton.extended(
        onPressed: () => _showAddDialog(brands, categoryName),
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('브랜드 추가', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

extension WidgetExt on Widget {
  Widget applyFloatingActionButton(FloatingActionButton fab) {
    return Scaffold(
      body: this,
      floatingActionButton: fab,
    );
  }
}
