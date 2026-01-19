import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_service.dart';

class AdminProductListScreen extends StatefulWidget {
  const AdminProductListScreen({super.key});

  @override
  State<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends State<AdminProductListScreen> {
  // Since ProductService uses streams, we might just consume the provider directly
  // or use a local filtered list if we want to implement search within this screen.
  
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final allProducts = productService.allProductsForAdmin;

    final filteredProducts = allProducts.where((product) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return product.title.toLowerCase().contains(q) ||
          product.brand.toLowerCase().contains(q) ||
          product.sellerName.toLowerCase().contains(q);
    }).toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Product Management',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Products',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        image: product.imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(product.imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: product.imageUrl.isEmpty
                          ? const Icon(Icons.image_not_supported)
                          : null,
                    ),
                    title: Text(product.title),
                    subtitle: Text(
                        '${product.brand} • ${product.price}원 • ${product.sellerName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(product.status.toString().split('.').last),
                          backgroundColor: _getStatusColor(product.status),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'DELETE') {
                              _confirmDelete(context, product);
                            } else if (value == 'HIDE') {
                              _updateStatus(context, product, ProductStatus.hidden);
                            } else if (value == 'ACTIVE') {
                              _updateStatus(context, product, ProductStatus.forSale);
                            }
                          },
                          itemBuilder: (context) => [
                            if (product.status != ProductStatus.forSale)
                              const PopupMenuItem(
                                value: 'ACTIVE',
                                child: Text('Set Active'),
                              ),
                            if (product.status != ProductStatus.hidden)
                              const PopupMenuItem(
                                value: 'HIDE',
                                child: Text('Hide (Admin)'),
                              ),
                            const PopupMenuItem(
                              value: 'DELETE',
                              child: Text('Delete Permanently', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.forSale:
        return Colors.greenAccent;
      case ProductStatus.reserved:
        return Colors.orangeAccent;
      case ProductStatus.soldOut:
        return Colors.grey;
      case ProductStatus.hidden:
        return Colors.redAccent;
    }
  }

  Future<void> _updateStatus(BuildContext context, Product product, ProductStatus status) async {
    try {
      await context.read<ProductService>().updateProductStatus(product.id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated to ${status.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Assuming removeProduct exists and takes ID
      await context.read<ProductService>().removeProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
