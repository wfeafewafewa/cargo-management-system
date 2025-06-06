import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/admin_dashboard.dart';
import 'screens/driver_management_screen.dart';
import 'screens/performance_monitor.dart';
import 'screens/system_settings.dart';
import 'screens/delivery_management_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/advanced_reports_screen.dart';
import 'screens/sales_management_screen.dart';
import 'screens/data_management_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/driver_dashboard_screen.dart';

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
        '/main': (context) => MainNavigationScreen(),
        '/admin-dashboard': (context) => AdminDashboard(),
        '/driver-dashboard': (context) => DriverManagementScreen(),
        '/performance-monitor': (context) => PerformanceMonitor(),
        '/system-settings': (context) => SystemSettingsScreen(),
        '/delivery-management': (context) => DeliveryManagementScreen(),
        '/driver-management': (context) => DriverManagementScreen(),
        '/advanced-reports': (context) => AdvancedReportsScreen(),
        '/sales-management': (context) => SalesManagementScreen(),
        '/data-management': (context) => DataManagementScreen(),
        // 新しいルートを追加
        '/role-selection': (context) => RoleSelectionScreen(),
        '/driver-app': (context) => DriverDashboardScreen(),
      },
    );
  }
}

// AuthWrapperを修正：ログイン後はMainNavigationScreenに遷移
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
          // ログイン済みの場合、MainNavigationScreenに遷移
          return MainNavigationScreen();
        }

        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
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
                      // 新しいボタンを追加
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/role-selection');
                          },
                          icon: Icon(Icons.psychology),
                          label: Text('役割選択画面テスト'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/driver-app');
                          },
                          icon: Icon(Icons.drive_eta),
                          label: Text('ドライバーアプリテスト'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
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
        user = await _authService.registerWithEmail(
          _emailController.text,
          _passwordController.text,
        );

        if (user != null) {
          await _firestoreService.createOrUpdateUser(
            userId: user.uid,
            email: user.email!,
            role: 'admin',
            name: _emailController.text.split('@')[0],
          );
        }
      } else {
        user = await _authService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }

      if (user != null) {
        // ログイン成功時はAuthWrapperが自動的にMainNavigationScreenにリダイレクト
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

      User? user = await _authService.signInWithEmail(email, password);

      if (user == null) {
        user = await _authService.registerWithEmail(email, password);

        if (user != null) {
          await _firestoreService.createOrUpdateUser(
            userId: user.uid,
            email: email,
            role: role,
            name: role == 'admin' ? '管理者' : 'テストドライバー',
          );
        }
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
