import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<bool> _confirmDeleteAccount(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까? 모든 데이터가 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '탈퇴',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserService>().currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('설정'),
        ),
        body: const Center(
          child: Text(
            '설정을 보려면 로그인이 필요합니다.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '계정',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '회원 탈퇴',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '탈퇴 시 모든 데이터가 삭제됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final confirm = await _confirmDeleteAccount(context);
                      if (!confirm) {
                        return;
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      try {
                        await context.read<UserService>().deleteAccount();
                        if (!context.mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                        );
                        navigator.pop();
                      } on FirebaseAuthException catch (error) {
                        if (!context.mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              error.message ?? '회원 탈퇴에 실패했습니다.',
                            ),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('회원 탈퇴에 실패했습니다.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('회원 탈퇴'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
