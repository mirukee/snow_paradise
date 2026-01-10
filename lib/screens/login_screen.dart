import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(), // 위쪽 여백 자동 조절

              // 1. 로고 영역
              // 실제 로고 이미지가 있다면 Image.asset을 쓰세요.
              // 지금은 텍스트와 아이콘으로 멋을 냈습니다.
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.ac_unit, // 눈꽃 아이콘
                      size: 60,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Snow Paradise',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900, // 아주 굵게
                      letterSpacing: 1.5, // 자간 넓게
                      fontFamily: 'Roboto', // 폰트는 기본 폰트
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '설원 위의 모든 거래',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const Spacer(), // 중간 여백

              // 2. 소셜 로그인 버튼들
              
              // 카카오 로그인
              _buildLoginButton(
                onPressed: () => _goToMain(context),
                backgroundColor: const Color(0xFFFEE500), // 카카오 노란색
                text: '카카오로 시작하기',
                textColor: Colors.black.withOpacity(0.85),
                icon: Icons.chat_bubble, // 카카오톡 아이콘 대신 말풍선
              ),
              const SizedBox(height: 12),

              // 구글 로그인
              _buildLoginButton(
                onPressed: () => _goToMain(context),
                backgroundColor: Colors.white,
                text: 'Google로 시작하기',
                textColor: Colors.black,
                icon: Icons.g_mobiledata, // 구글 아이콘 대체
                hasBorder: true,
              ),
              const SizedBox(height: 12),

              // 애플 로그인
              _buildLoginButton(
                onPressed: () => _goToMain(context),
                backgroundColor: Colors.black,
                text: 'Apple로 시작하기',
                textColor: Colors.white,
                icon: Icons.apple,
              ),

              const SizedBox(height: 40),
              
              // 3. 둘러보기 (로그인 없이 입장)
              TextButton(
                onPressed: () => _goToMain(context),
                child: Text(
                  '로그인 없이 둘러보기',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

// [수정] 메인으로 가는 게 아니라, 이전 화면(마이페이지)으로 돌아가며 'true' 반환
  void _goToMain(BuildContext context) {
    Navigator.pop(context, true); // true = 로그인 성공!
  }

  // 버튼 만드는 위젯 (코드 중복 방지)
  Widget _buildLoginButton({
    required VoidCallback onPressed,
    required Color backgroundColor,
    required String text,
    required Color textColor,
    required IconData icon,
    bool hasBorder = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // 요즘 스타일 둥근 모서리
          side: hasBorder
              ? BorderSide(color: Colors.grey[300]!)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}