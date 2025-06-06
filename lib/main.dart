import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

// 修正版の画面をインポート
import 'screens/admin_dashboard.dart';
import 'screens/delivery_management_screen.dart' as delivery;
import 'screens/driver_management_screen.dart' as driver;
import 'screens/driver_dashboard_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/sales_management_unified.dart'; // 追加

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '軽貨物業務管理システム',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ja', 'JP'),
      ],
      home: AuthWrapper(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/role-selection': (context) => RoleSelectionScreen(),
        '/admin-dashboard': (context) => AdminDashboard(),
        '/delivery-management': (context) =>
            delivery.DeliveryManagementScreen(),
        '/driver-management': (context) => driver.DriverManagementScreen(),
        '/driver-app': (context) => DriverDashboardScreen(),
        '/sales-management': (context) => SalesManagementUnifiedScreen(), // 追加
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// AuthWrapperを修正
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // ログイン成功時はRoleSelectionScreenに遷移
          return RoleSelectionScreen();
        }

        return LoginScreen();
      },
    );
  }
}

// 一時的なテスト用ナビゲーション画面
class TestNavigationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('テスト用ナビゲーション'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 3, // 2から3に変更
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildNavCard(
              context,
              '管理者ダッシュボード',
              Icons.dashboard,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminDashboard()),
              ),
            ),
            _buildNavCard(
              context,
              '配送案件管理',
              Icons.local_shipping,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => delivery.DeliveryManagementScreen()),
              ),
            ),
            _buildNavCard(
              context,
              'ドライバー管理',
              Icons.people,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => driver.DriverManagementScreen()),
              ),
            ),
            _buildNavCard(
              context,
              'ドライバーアプリ',
              Icons.drive_eta,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => DriverDashboardScreen()),
              ),
            ),
            _buildNavCard(
              context,
              '管理者メイン画面',
              Icons.admin_panel_settings,
              Colors.indigo,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        MainNavigationScreen(userRole: 'admin')),
              ),
            ),
            _buildNavCard(
              context,
              'ドライバーメイン画面',
              Icons.drive_eta,
              Colors.teal,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        MainNavigationScreen(userRole: 'driver')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegisterMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              margin: EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 64,
                        color: Colors.blue[600],
                      ),
                      SizedBox(height: 16),
                      Text(
                        '軽貨物業務管理システム',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '株式会社ダブルエッチ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 32),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'メールアドレス',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'パスワード',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  _isRegisterMode ? '登録' : 'ログイン',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isRegisterMode = !_isRegisterMode;
                          });
                        },
                        child: Text(
                          _isRegisterMode ? 'ログインはこちら' : 'アカウント登録はこちら',
                          style: TextStyle(color: Colors.blue[600]),
                        ),
                      ),
                      SizedBox(height: 24),
                      Divider(),
                      SizedBox(height: 16),
                      Text(
                        'テスト用アカウント',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : () => _testLogin('admin'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('管理者テスト'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _testLogin('driver'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('ドライバーテスト'),
                            ),
                          ),
                        ],
                      ),
                      // 一時的に直接画面へのボタンを追加
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TestNavigationScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.dashboard),
                          label: Text('画面テスト（認証スキップ）'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メールアドレスとパスワードを入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user;
      if (_isRegisterMode) {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        user = credential.user;
      } else {
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        user = credential.user;
      }

      if (user != null) {
        // ログイン成功時はAuthWrapperが自動的にリダイレクト
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testLogin(String role) async {
    setState(() => _isLoading = true);

    try {
      final email = role == 'admin'
          ? 'admin@doubletech.co.jp'
          : 'driver@doubletech.co.jp';
      final password = '${role}123';

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        // アカウントが存在しない場合は作成
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('テストログインエラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
