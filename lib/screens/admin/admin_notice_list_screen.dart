import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/notice_model.dart';
import 'package:intl/intl.dart';

class AdminNoticeListScreen extends StatefulWidget {
  const AdminNoticeListScreen({super.key});

  @override
  State<AdminNoticeListScreen> createState() => _AdminNoticeListScreenState();
}

class _AdminNoticeListScreenState extends State<AdminNoticeListScreen> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
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
                  'Notice Management',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showAddEditDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Notice'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('notices')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No notices found'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final notice = NoticeModel.fromJson(
                        doc.data() as Map<String, dynamic>,
                        id: doc.id,
                      );
                      return ListTile(
                        title: Text(notice.title),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt),
                        ),
                        onTap: () => _showAddEditDialog(notice: notice),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteNotice(notice.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog({NoticeModel? notice}) {
    final titleController = TextEditingController(text: notice?.title ?? '');
    final contentController =
        TextEditingController(text: notice?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notice == null ? 'Add Notice' : 'Edit Notice'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return;

              if (notice == null) {
                await _firestore.collection('notices').add({
                  'title': title,
                  'content': content,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                await _firestore.collection('notices').doc(notice.id).update({
                  'title': title,
                  'content': content,
                });
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotice(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to delete this notice?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('notices').doc(id).delete();
    }
  }
}
