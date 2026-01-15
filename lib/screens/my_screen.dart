import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'like_list_screen.dart';
import '../models/user_model.dart';
import '../providers/user_service.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserService>().currentUser;
    if (user == null) {
      return _buildGuestView(context);
    }
    return _buildUserView(context, user);
  }

  // ==========================================
  // 1. 로그인 안 했을 때 보이는 화면 (Guest View)
  // ==========================================
  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: _buildSocialButton(
                  context,
                  backgroundColor: Colors.white,
                  borderColor: Colors.grey.shade400,
                  textColor: Colors.black,
                  text: 'Google로 계속하기',
                  logo: Image.network(
                    // 구글 공식 G 로고 (PNG)
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                    width: 20,
                    height: 20,
                  ),
                  elevation: 0,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final user = await context.read<UserService>().loginWithGoogle();
                      if (user == null) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(content: Text('구글 로그인 완료!')),
                      );
                    } on FirebaseAuthException catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(error.message ?? '로그인에 실패했습니다.')),
                      );
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('로그인에 실패했습니다.')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final user =
                        await context.read<UserService>().signInAnonymously();
                    if (user == null) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(content: Text('게스트 로그인 완료!')),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('게스트 로그인에 실패했습니다.')),
                    );
                  }
                },
                child: Text(
                  '게스트로 체험하기',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _buildSocialButton(
                  context,
                  backgroundColor: const Color(0xFFFEE500),
                  borderColor: Colors.transparent,
                  textColor: Colors.black,
                  text: 'Kakao로 계속하기',
                  logo: Image.network(
                    // 카카오톡 심볼 (PNG)
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/KakaoTalk_logo.svg/800px-KakaoTalk_logo.svg.png',
                    width: 20,
                    height: 20,
                  ),
                  elevation: 1,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('카카오 로그인은 준비 중입니다.')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _buildSocialButton(
                  context,
                  backgroundColor: Colors.black,
                  borderColor: Colors.transparent,
                  textColor: Colors.white,
                  text: 'Apple로 계속하기',
                  logo: const Icon(Icons.apple, color: Colors.white, size: 20),
                  elevation: 1,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('애플 로그인은 준비 중입니다.')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. 로그인 했을 때 보이는 화면 (User View - 기존 코드)
  // ==========================================
  Widget _buildUserView(BuildContext context, User user) {
    final primaryColor = Theme.of(context).primaryColor;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final userModel = data == null ? null : UserModel.fromJson(data);
        final displayName = userModel?.nickname.isNotEmpty == true
            ? userModel!.nickname
            : (user.displayName ?? user.email ?? '사용자');
        final email =
            userModel?.email.isNotEmpty == true ? userModel!.email : user.email;
        final profileImageUrl = userModel?.profileImageUrl?.trim();
        final ImageProvider avatarImage =
            (profileImageUrl != null && profileImageUrl.isNotEmpty)
                ? NetworkImage(profileImageUrl)
                : const AssetImage('assets/images/user_default.png');

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              '나의 파라다이스',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프로필 영역
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: avatarImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 14, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email?.isNotEmpty == true ? email! : 'Google 계정',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: const Text(
                          '프로필 수정',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),

            // 설질 (Snow Quality)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '나의 설질(Snow Quality)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            '최상급 슬로프',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.ac_unit, size: 16, color: primaryColor),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '매너가 좋을수록 설질이 좋아져요!',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            // 대시보드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDashboardItem(context, Icons.list_alt, '판매내역'),
                  _buildDashboardItem(context, Icons.shopping_bag_outlined, '구매내역'),
                  _buildDashboardItem(
                    context,
                    Icons.favorite_border,
                    '관심목록',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LikeListScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

            // 메뉴 리스트
            _buildListTile('자주 묻는 질문'),
            _buildListTile('공지사항'),
            _buildListTile('약관 및 정책'),
            _buildListTile(
              '설정',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            _buildListTile(
              '로그아웃',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await context.read<UserService>().signOut();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('로그아웃 되었습니다.')),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('로그아웃에 실패했습니다.')),
                  );
                }
              },
            ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardItem(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(String title, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required String text,
    required Widget logo,
    required double elevation,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        elevation: elevation,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: borderColor == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: logo)),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}
