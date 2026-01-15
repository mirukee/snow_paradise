import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider()..loadUser(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final TextEditingController _nicknameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _didSetInitialNickname = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ProfileProvider provider) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    provider.selectImage(File(picked.path));
  }

  Future<void> _saveProfile(ProfileProvider provider) async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    final success = await provider.saveProfile(nickname);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '수정 완료' : '수정에 실패했습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = provider.user;
        if (user == null) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('로그인이 필요합니다.')),
          );
        }

        if (!_didSetInitialNickname) {
          _didSetInitialNickname = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _nicknameController.text = user.nickname;
          });
        }

        final profileImageUrl = user.profileImageUrl?.trim();
        final ImageProvider avatarImage;
        if (provider.selectedImage != null) {
          avatarImage = FileImage(provider.selectedImage!);
        } else if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          avatarImage = NetworkImage(profileImageUrl);
        } else {
          avatarImage = const AssetImage('assets/images/user_default.png');
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              '프로필 수정',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              TextButton(
                onPressed:
                    provider.isSaving ? null : () => _saveProfile(provider),
                child: provider.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap:
                        provider.isSaving ? null : () => _pickImage(provider),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: avatarImage,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '이메일',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email.isEmpty ? '이메일 없음' : user.email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    hintText: '닉네임을 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
