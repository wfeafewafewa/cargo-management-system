import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard.dart';
import 'delivery_management_screen.dart';
import 'driver_management_screen.dart';
import 'sales_management_unified.dart';
import 'driver_dashboard_screen.dart';
import 'role_selection_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String userRole;

  const MainNavigationScreen({Key? key, required this.userRole})
      : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late String _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.userRole;
  }

  List<Widget> get _adminScreens => [
        AdminDashboard(),
        DeliveryManagementScreen(),
        DriverManagementScreen(),
        SalesManagementUnifiedScreen(),
      ];

  List<Widget> get _driverScreens => [
        DriverDashboardScreen(),
      ];

  List<BottomNavigationBarItem> get _adminNavItems => [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'ダッシュボード',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping),
          label: '配送案件管理',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'ドライバー管理',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: '売上管理',
        ),
      ];

  List<BottomNavigationBarItem> get _driverNavItems => [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'ダッシュボード',
        ),
      ];

  void _switchRole() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
      (route) => false,
    );
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログアウトに失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _currentRole == 'admin';
    final screens = isAdmin ? _adminScreens : _driverScreens;
    final navItems = isAdmin ? _adminNavItems : _driverNavItems;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue[600],
        unselectedItemColor: Colors.grey[600],
        items: navItems,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue[600],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '軽貨物業務管理システム',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '現在のロール: ${isAdmin ? "管理者" : "ドライバー"}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              ListTile(
                leading: Icon(Icons.dashboard),
                title: Text('ダッシュボード'),
                selected: _selectedIndex == 0,
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.local_shipping),
                title: Text('配送案件管理'),
                selected: _selectedIndex == 1,
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.people),
                title: Text('ドライバー管理'),
                selected: _selectedIndex == 2,
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.analytics),
                title: Text('売上管理'),
                selected: _selectedIndex == 3,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                },
              ),
              Divider(),
            ],
            ListTile(
              leading: Icon(Icons.swap_horiz),
              title: Text('ロール切り替え'),
              onTap: () {
                Navigator.pop(context);
                _switchRole();
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('ログアウト'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
