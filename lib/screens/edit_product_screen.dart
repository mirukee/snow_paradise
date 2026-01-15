import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;

  String _selectedCategory = '기타';
  final List<String> _categories = [
    '스노우보드',
    '스키',
    '의류',
    '보호구',
    '시즌권',
    '시즌방',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _priceController = TextEditingController(text: _formatNumber(widget.product.price));
    _descController = TextEditingController(text: widget.product.description);
    if (_categories.contains(widget.product.category)) {
      _selectedCategory = widget.product.category;
    } else if (_categories.contains(widget.product.brand)) {
      _selectedCategory = widget.product.brand;
    }
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

    final updatedProduct = Product(
      id: widget.product.id,
      docId: widget.product.docId,
      createdAt: widget.product.createdAt,
      title: title,
      price: price,
      brand: widget.product.brand,
      category: _selectedCategory,
      condition: widget.product.condition,
      imageUrl: widget.product.imageUrl,
      localImagePath: widget.product.localImagePath,
      description: description,
      size: widget.product.size,
      year: widget.product.year,
      sellerName: widget.product.sellerName,
      sellerProfile: widget.product.sellerProfile,
      sellerId: widget.product.sellerId,
      status: widget.product.status,
    );

    await context.read<ProductService>().updateProduct(updatedProduct);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '상품 수정',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '카테고리 선택',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
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
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
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
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '글 제목',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 18),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
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
              TextField(
                controller: _descController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '게시글 내용을 작성해주세요.',
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
