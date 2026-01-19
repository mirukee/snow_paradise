import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_auth_provider.dart';
import 'admin_user_list_screen.dart';
import 'admin_product_list_screen.dart';
import 'admin_notice_list_screen.dart';
import 'admin_terms_screen.dart';
import 'admin_report_list_screen.dart';
import 'admin_brand_management_screen.dart';
import 'admin_home_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminHomeScreen(), // 통계 대시보드 홈 화면
    const AdminUserListScreen(),
    const AdminProductListScreen(),
    const AdminNoticeListScreen(),
    const AdminReportListScreen(),
    const AdminBrandManagementScreen(),
    const AdminTermsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AdminAuthProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snow Paradise Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_bag),
                label: Text('Products'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications),
                label: Text('Notices'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.report_problem),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category),
                label: Text('Brands'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description),
                label: Text('Terms'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
