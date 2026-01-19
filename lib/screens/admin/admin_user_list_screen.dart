import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/user_service.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await context.read<UserService>().getAllUsers();
      setState(() {
        _users = users;
      });
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 목록 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBan(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.isBanned ? '정지 해제' : '사용자 정지'),
        content: Text('${user.nickname}님을 ${user.isBanned ? '정지 해제' : '정지'} 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await context
          .read<UserService>()
          .updateUserBanStatus(user.uid, !user.isBanned);
      await _loadUsers(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상태가 변경되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('작업 실패: $e')),
        );
      }
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
            Text(
              'User Management',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nickname')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Created At')),
                    DataColumn(label: Text('Is Admin')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _users.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: user.profileImageUrl != null
                                  ? NetworkImage(user.profileImageUrl!)
                                  : null,
                              child: user.profileImageUrl == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(user.nickname),
                          ],
                        )),
                        DataCell(Text(user.email)),
                        DataCell(Text(user.createdAt.toString().split(' ')[0])),
                        DataCell(
                          user.isAdmin
                               ? const Chip(label: Text('Admin'), backgroundColor: Colors.amberAccent)
                               : const Text('User'),
                        ),
                        DataCell(
                           user.isBanned
                               ? const Text('Banned', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                               : const Text('Active', style: TextStyle(color: Colors.green)),
                        ),
                        DataCell(
                          IconButton(
                            icon: Icon(
                              user.isBanned ? Icons.lock_open : Icons.block,
                              color: user.isBanned ? Colors.green : Colors.red,
                            ),
                            tooltip: user.isBanned ? 'Unban User' : 'Ban User',
                            onPressed: () => _toggleBan(user),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
