import 'package:flutter/material.dart';
import 'login_screen.dart'; // 로그인 화면 연결

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  // 로그인 상태 변수 (false: 비로그인, true: 로그인됨)
  bool _isLoggedIn = false;

  // 로그인 화면으로 이동하는 함수
  Future<void> _navigateToLogin() async {
    // LoginScreen으로 이동하고, 돌아올 때 결과를 기다림(await)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    // 로그인이 성공해서 돌아왔다면(true), 화면을 갱신
    if (result == true) {
      setState(() {
        _isLoggedIn = true;
      });
      
      // 환영 스낵바 띄우기
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('환영합니다! 로그인 되었습니다.')),
      );
    }
  }

  // 로그아웃 함수
  void _logout() {
    setState(() {
      _isLoggedIn = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그아웃 되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 여부에 따라 다른 화면 보여주기
    if (!_isLoggedIn) {
      return _buildGuestView();
    } else {
      return _buildUserView();
    }
  }

  // ==========================================
  // 1. 로그인 안 했을 때 보이는 화면 (Guest View)
  // ==========================================
  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              '로그인이 필요한 서비스입니다.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '회원이 되어 다양한 혜택을 누려보세요!',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            
            // 로그인 버튼
            ElevatedButton(
              onPressed: _navigateToLogin, // 로그인 화면으로 이동
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text(
                '로그인 / 회원가입',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. 로그인 했을 때 보이는 화면 (User View - 기존 코드)
  // ==========================================
  Widget _buildUserView() {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '나의 파라다이스',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // 설정 아이콘 누르면 임시 로그아웃 기능 연결
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('설정'),
                  content: const Text('로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      }, 
                      child: const Text('로그아웃', style: TextStyle(color: Colors.red))
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
          ),
        ],
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
                          image: const DecorationImage(
                            image: NetworkImage('https://picsum.photos/200'),
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
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '보드타는약대생',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '남양주시 다산동 #123456',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text(
                      '프로필 보기',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
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
                  _buildDashboardItem(context, Icons.favorite_border, '관심목록'),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

            // 메뉴 리스트
            _buildListTile('동네생활 글'),
            _buildListTile('스키장 친구 찾기'),
            const Divider(height: 1),
            _buildListTile('자주 묻는 질문'),
            _buildListTile('공지사항'),
            _buildListTile('약관 및 정책'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem(BuildContext context, IconData icon, String label) {
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
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
    );
  }

  Widget _buildListTile(String title) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () {},
    );
  }
}