import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminTermsScreen extends StatefulWidget {
  const AdminTermsScreen({super.key});

  @override
  State<AdminTermsScreen> createState() => _AdminTermsScreenState();
}

class _AdminTermsScreenState extends State<AdminTermsScreen> {
  final _termsController = TextEditingController();
  final _privacyController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() => _isLoading = true);
    try {
      final termsDoc =
          await _firestore.collection('common').doc('terms').get();
      final privacyDoc =
          await _firestore.collection('common').doc('privacy').get();

      if (mounted) {
        _termsController.text = termsDoc.data()?['content'] ?? '';
        _privacyController.text = privacyDoc.data()?['content'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load terms: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTerms() async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('common').doc('terms').set({
        'content': _termsController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('common').doc('privacy').set({
        'content': _privacyController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                  'Terms & Privacy Management',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saveTerms,
                  icon: const Icon(Icons.save),
                  label: const Text('Save All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildEditorSection(
                      context,
                      'Terms of Service',
                      _termsController,
                    ),
                    const SizedBox(height: 24),
                    _buildEditorSection(
                      context,
                      'Privacy Policy',
                      _privacyController,
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

  Widget _buildEditorSection(
    BuildContext context,
    String title,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 15,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter legal text here...',
          ),
        ),
      ],
    );
  }
}
