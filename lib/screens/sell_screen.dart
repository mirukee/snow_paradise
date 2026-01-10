import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 숫자 입력 제한용

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

  // 선택된 카테고리를 저장할 변수
  String _selectedCategory = '기타';
  final List<String> _categories = ['스키', '스노우보드', '의류', '시즌권', '시즌방', '기타'];
  
  // 가짜 이미지 리스트 (UI 테스트용)
  // 나중에 image_picker 패키지를 쓰면 실제 파일로 바뀝니다.
  final List<String> _selectedImages = [];

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
            onPressed: () {
              // 등록 완료 처리 (추후 구현)
              if (_titleController.text.isEmpty || _priceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목과 가격을 입력해주세요.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('상품이 등록되었습니다! (가짜)')),
                );
                // 입력창 초기화
                _titleController.clear();
                _priceController.clear();
                _descController.clear();
                setState(() {
                  _selectedImages.clear();
                });
              }
            },
            child: const Text(
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
                    onTap: () {
                      // 실제로는 여기서 갤러리를 엽니다.
                      // 지금은 UI 테스트를 위해 가짜 회색 박스를 추가합니다.
                      setState(() {
                        if (_selectedImages.length < 10) {
                          _selectedImages.add('dummy_image');
                        }
                      });
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
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
                                    color: Colors.grey[200], // 이미지 대신 회색 배경
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  // 실제 이미지가 있다면 Image.file(...) 등을 사용
                                  child: const Icon(Icons.image, color: Colors.grey),
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

              // [카테고리 선택 라벨]
              const Text(
                '카테고리 선택',
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87
                ),
              ),
              const SizedBox(height: 12),

              // [수정된 UI] 가로 스크롤 알약 버튼 (Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          // 선택되면 검은색, 아니면 흰색 배경
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(20), // 둥근 알약 모양
                          border: Border.all(
                            // 선택 안 됐을 때만 회색 테두리
                            color: isSelected ? Colors.black : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
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