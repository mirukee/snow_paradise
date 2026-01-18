import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 숫자 입력 제한용
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/main_tab_provider.dart';
import '../providers/user_service.dart';
import '../services/user_service.dart' as profile_service;
import '../widgets/product_image.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  // 입력값들을 저장할 변수들
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isUploading = false;

  // 선택된 카테고리를 저장할 변수
  String _selectedCategory = '기타';
  final List<String> _categories = ['스노우보드', '스키', '의류', '보호구', '기타'];
  
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];

  // 가격 포맷팅 (숫자만 입력받아 3자리마다 콤마 찍기)
  void _formatPrice(String value) {
    if (value.isEmpty) return;
    
    // 숫자 아닌 문자 제거
    value = value.replaceAll(RegExp(r'[^0-9]'), ''); 
    if (value.isEmpty) return;

    final number = int.parse(value);
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
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
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _selectedImages.add(picked);
      });
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요. 권한을 확인해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            // 닫기 (메인 탭에서는 보통 안 쓰지만, 모달로 띄울 때 사용)
          },
        ),
        title: const Text(
          '내 물건 팔기',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading
                ? null
                : () async {
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

              final productId = DateTime.now().millisecondsSinceEpoch.toString();
              final now = DateTime.now();
              final currentUser = context.read<UserService>().currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그인이 필요합니다.')),
                );
                return;
              }
              String sellerName =
                  currentUser.displayName ?? currentUser.email ?? '익명';
              String sellerProfile = '';
              try {
                final profileUser = await profile_service.UserService()
                    .getUser(currentUser.uid);
                final nickname = profileUser?.nickname.trim() ?? '';
                if (nickname.isNotEmpty) {
                  sellerName = nickname;
                }
                sellerProfile = profileUser?.profileImageUrl?.trim() ?? '';
              } catch (_) {
                sellerProfile = '';
              }
              final localImagePath =
                  _selectedImages.isNotEmpty ? _selectedImages.first.path : null;
              final product = Product(
                id: productId,
                createdAt: now,
                title: title,
                price: price,
                brand: _selectedCategory,
                category: _selectedCategory,
                condition: '중고',
                imageUrl: '',
                localImagePath: localImagePath,
                description: description,
                size: 'Free',
                year: '${now.year}년',
                sellerName: sellerName,
                sellerProfile: sellerProfile,
                sellerId: currentUser.uid,
              );

              final messenger = ScaffoldMessenger.of(context);
              setState(() {
                _isUploading = true;
              });
              try {
                await context.read<ProductService>().addProduct(product);
                if (!mounted) return;
                _titleController.clear();
                _priceController.clear();
                _descController.clear();
                setState(() {
                  _selectedImages.clear();
                });
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop();
                } else {
                  context.read<MainTabProvider>().setIndex(0);
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('등록 완료!')),
                );
              } catch (_) {
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('업로드에 실패했습니다.')),
                );
              } finally {
                if (!mounted) return;
                setState(() {
                  _isUploading = false;
                });
              }
            },
            child: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '완료',
                    style: TextStyle(
                      color: Colors.orange, // 포인트 컬러
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 사진 추가 영역 (가로 스크롤)
              Row(
                children: [
                  // 카메라 버튼
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.grey[400]),
                          Text(
                            '${_selectedImages.length}/10',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 선택된 사진 리스트
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: buildLocalImageFromPath(
                                      _selectedImages[index].path,
                                      fit: BoxFit.cover,
                                      errorIconSize: 24,
                                      loadingWidget: const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                ),
                                // 삭제 버튼 (X)
                                Positioned(
                                  top: -8,
                                  right: -8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.close,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 12),

              const Text(
                '카테고리 선택',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                dropdownColor: Colors.white,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),


              // 2. 제목 입력
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '글 제목',
                  border: InputBorder.none, // 밑줄 없애기 (깔끔하게)
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 18),
              ),
              
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 3. 가격 입력
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number, // 숫자 키패드
                onChanged: _formatPrice,
                decoration: const InputDecoration(
                  hintText: '가격 (원)',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const Divider(height: 1),
              const SizedBox(height: 12),

              // 4. 내용 입력
              TextField(
                controller: _descController,
                maxLines: 10, // 여러 줄 입력 가능
                decoration: const InputDecoration(
                  hintText: '게시글 내용을 작성해주세요. (가품 및 판매금지품목은 게시가 제한될 수 있어요.)',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
