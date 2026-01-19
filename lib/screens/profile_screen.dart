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
  final TextEditingController _bioController = TextEditingController();
  // 태그 입력/삭제를 위한 컨트롤러 X -> 단순 리스트 관리
  final List<String> _tags = [];
  
  final ImagePicker _imagePicker = ImagePicker();
  bool _didSetInitialData = false;
  
  static const Color _primaryBlue = Color(0xFF3E97EA);
  static const Color _backgroundLight = Color(0xFFF6F7F8);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF111518);
  static const Color _textGrey = Color(0xFF637688);

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showImagePickerModal(ProfileProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: _textDark),
                title: const Text('앨범에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('기본 이미지로 변경', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  provider.setDefaultImage();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ProfileProvider provider) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    // 이미지 선택 후 바이트 로딩 등 비동기 처리 대기
    await provider.selectImage(picked);
  }

  Future<void> _saveProfile(ProfileProvider provider) async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    final success = await provider.saveProfile(
      nickname: nickname,
      styleTags: _tags,
      bio: _bioController.text.trim(),
    );
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 수정되었습니다.')),
      );
      Navigator.pop(context); // 성공 시 화면 닫기
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  void _addTag() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('태그 추가'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '예: 스노우보드, 라이딩',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final tag = controller.text.trim();
                Navigator.pop(context, tag);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null && value is String && value.isNotEmpty) {
        if (!_tags.contains(value)) {
          setState(() {
            _tags.add(value);
          });
        }
      }
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: _surfaceLight,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = provider.user;
        if (user == null) {
          return const Scaffold(
            backgroundColor: _surfaceLight,
            body: Center(child: Text('로그인이 필요합니다.')),
          );
        }

        // 초기 데이터 로딩 (한 번만 실행)
        if (!_didSetInitialData) {
          _didSetInitialData = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _nicknameController.text = user.nickname;
              _bioController.text = user.bio; // Bio 초기화
              _tags.clear();
              _tags.addAll(user.styleTags); // Tags 초기화
            });
          });
        }
        
        // 이미지 소스 결정
        // 1. 기본 이미지 플래그가 true면 무조건 기본 이미지
        // 2. 새로 선택한 이미지 (bytes)
        // 3. 기존 프로필 URL
        // 4. 기본 이미지
        final ImageProvider avatarImage;
        if (provider.isDefaultImage) {
          avatarImage = const AssetImage('assets/images/user_default.png');
        } else if (provider.selectedImageBytes != null) {
          avatarImage = MemoryImage(provider.selectedImageBytes!);
        } else if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
          avatarImage = NetworkImage(user.profileImageUrl!);
        } else {
          avatarImage = const AssetImage('assets/images/user_default.png');
        }

        return Scaffold(
          backgroundColor: _backgroundLight, // 배경색: surface-light/dark -> background-light
          body: Column(
            children: [
              // Custom Header (SafeArea + AppBar content)
              Container(
                color: _surfaceLight,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 뒤로가기 버튼
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back, color: _textDark),
                        ),
                        // 타이틀
                        const Text(
                          '프로필 수정',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        // 완료 버튼
                        TextButton(
                          onPressed: provider.isSaving ? null : () => _saveProfile(provider),
                          child: provider.isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  '완료',
                                  style: TextStyle(
                                    color: _primaryBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    color: _surfaceLight,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 100, // 최소 높이 보장
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        // Avatar Section
                        Center(
                          child: GestureDetector(
                            onTap: provider.isSaving ? null : () => _showImagePickerModal(provider),
                            child: Stack(
                              children: [
                                // 프로필 이미지
                                Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[200],
                                    border: Border.all(
                                      color: Colors.grey[50]!, // slate-50 equivalent
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    image: DecorationImage(
                                      image: avatarImage,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                // 카메라 아이콘 오버레이
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _primaryBlue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _surfaceLight,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Nickname Input
                        const SizedBox(height: 32),
                        const Text(
                          '닉네임',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _backgroundLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _nicknameController,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: '닉네임을 입력하세요',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              suffixIcon: IconButton(
                                onPressed: () => _nicknameController.clear(),
                                icon: Icon(Icons.cancel, color: Colors.grey[400]),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        
                        // Style Tags Section
                        const Text(
                          '나의 겨울 스포츠 스타일',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._tags.map((tag) => Container(
                              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                              decoration: BoxDecoration(
                                color: _primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _primaryBlue.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tag,
                                    style: const TextStyle(
                                      color: _primaryBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _removeTag(tag),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: _primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            // 태그 추가 버튼
                            GestureDetector(
                              onTap: _addTag,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    style: BorderStyle.solid, // 원래 dashed 표현하기 어려우면 solid로 대체 또는 CustomPaint
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 18, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '태그 추가',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Bio Input
                        const Text(
                          '한 줄 소개',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: _backgroundLight,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                controller: _bioController,
                                maxLines: 5,
                                maxLength: 50,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                  color: _textDark,
                                ),
                                decoration: InputDecoration(
                                  hintText: '나를 표현하는 한마디를 적어주세요.',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  counterText: '', // 기본 카운터 숨김
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 16,
                              child: Text(
                                '${_bioController.text.length}/50',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // 하단 여백 확보
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

