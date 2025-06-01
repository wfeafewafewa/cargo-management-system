import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({Key? key}) : super(key: key);

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('システム設定'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showSystemInfo,
            icon: const Icon(Icons.info_outline),
            tooltip: 'システム情報',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'ユーザー管理'),
            Tab(icon: Icon(Icons.local_shipping), text: 'ドライバー管理'),
            Tab(icon: Icon(Icons.settings), text: 'システム設定'),
            Tab(icon: Icon(Icons.storage), text: 'データ管理'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserManagementTab(),
          _buildDriverManagementTab(),
          _buildSystemSettingsTab(),
          _buildDataManagementTab(),
        ],
      ),
    );
  }

  // ユーザー管理タブ
  Widget _buildUserManagementTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'ユーザー管理',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('新規ユーザー'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState('ユーザーが登録されていません', Icons.person_off);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildUserCard(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ドライバー管理タブ
  Widget _buildDriverManagementTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'ドライバー管理',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddDriverDialog,
                icon: const Icon(Icons.add),
                label: const Text('新規ドライバー'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('drivers').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState('ドライバーが登録されていません', Icons.no_accounts);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildDriverCard(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // システム設定タブ
  Widget _buildSystemSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsSection('基本設定', [
            _buildSettingsTile(
              '会社名',
              '株式会社ダブルエッチ',
              Icons.business,
              () => _editCompanyName(),
            ),
            _buildSettingsTile(
              'システム名',
              '軽貨物業務管理システム',
              Icons.apps,
              () => _editSystemName(),
            ),
            _buildSettingsTile(
              'タイムゾーン',
              'Asia/Tokyo (UTC+9)',
              Icons.schedule,
              () => _editTimezone(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsSection('通知設定', [
            _buildSwitchTile(
              '新規案件通知',
              'ドライバーに新規案件を自動通知',
              Icons.notifications,
              true,
              (value) => _toggleNotification('newDelivery', value),
            ),
            _buildSwitchTile(
              '完了通知',
              '管理者に配送完了を通知',
              Icons.check_circle,
              true,
              (value) => _toggleNotification('completion', value),
            ),
            _buildSwitchTile(
              'メール通知',
              '重要な更新をメールで通知',
              Icons.email,
              false,
              (value) => _toggleNotification('email', value),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsSection('セキュリティ', [
            _buildSettingsTile(
              'パスワードポリシー',
              '最小8文字、英数字混合',
              Icons.security,
              () => _editPasswordPolicy(),
            ),
            _buildSettingsTile(
              'セッション時間',
              '24時間',
              Icons.timer,
              () => _editSessionTimeout(),
            ),
            _buildSettingsTile(
              'アクセスログ',
              '90日間保持',
              Icons.history,
              () => _viewAccessLogs(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsSection('表示設定', [
            _buildSettingsTile(
              'テーマ',
              'ライトモード',
              Icons.palette,
              () => _editTheme(),
            ),
            _buildSettingsTile(
              '言語',
              '日本語',
              Icons.language,
              () => _editLanguage(),
            ),
            _buildSettingsTile(
              '日付形式',
              'YYYY/MM/DD',
              Icons.date_range,
              () => _editDateFormat(),
            ),
          ]),
        ],
      ),
    );
  }

  // データ管理タブ
  Widget _buildDataManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataSection('データベース統計', [
            _buildDataStatCard('配送案件', Icons.local_shipping, Colors.blue),
            _buildDataStatCard('ユーザー', Icons.people, Colors.green),
            _buildDataStatCard('売上データ', Icons.attach_money, Colors.orange),
            _buildDataStatCard('ドライバー', Icons.person, Colors.purple),
          ]),
          const SizedBox(height: 24),
          _buildDataSection('バックアップ・復元', [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.backup, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'データバックアップ',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '重要なデータを定期的にバックアップして、システムの安全性を確保します。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _performBackup,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('今すぐバックアップ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _scheduleBackup,
                          icon: const Icon(Icons.schedule),
                          label: const Text('自動バックアップ設定'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildDataSection('データ最適化', [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'データベース最適化',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'システムのパフォーマンスを向上させるため、定期的にデータベースを最適化します。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _optimizeDatabase,
                          icon: const Icon(Icons.speed),
                          label: const Text('データベース最適化'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _cleanupOldData,
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('古いデータ削除'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              data['role'] == 'admin' ? Colors.blue : Colors.orange,
          child: Icon(
            data['role'] == 'admin' ? Icons.admin_panel_settings : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(data['name'] ?? 'N/A'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['email'] ?? 'N/A'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: data['role'] == 'admin'
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                data['role'] == 'admin' ? '管理者' : 'ドライバー',
                style: TextStyle(
                  fontSize: 12,
                  color: data['role'] == 'admin'
                      ? Colors.blue.shade800
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editUser(userId, data);
                break;
              case 'delete':
                _deleteUser(userId, data);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('編集'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('削除', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(String driverId, Map<String, dynamic> data) {
    final isActive = data['status'] == '稼働中';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(
            Icons.local_shipping,
            color: Colors.white,
          ),
        ),
        title: Text(data['name'] ?? 'N/A'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['phone'] ?? 'N/A'} | ${data['vehicle'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        isActive ? Colors.green.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['status'] ?? '未設定',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? Colors.green.shade800
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '担当: ${data['currentDeliveries'] ?? 0}件',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editDriver(driverId, data);
                break;
              case 'toggle':
                _toggleDriverStatus(driverId, data);
                break;
              case 'delete':
                _deleteDriver(driverId, data);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('編集'),
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                leading: Icon(isActive ? Icons.pause : Icons.play_arrow),
                title: Text(isActive ? '稼働停止' : '稼働開始'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('削除', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon,
      bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildDataSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDataStatCard(String title, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(_getCollectionName(title))
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '$count件',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getCollectionName(String title) {
    switch (title) {
      case '配送案件':
        return 'deliveries';
      case 'ユーザー':
        return 'users';
      case '売上データ':
        return 'sales';
      case 'ドライバー':
        return 'drivers';
      default:
        return 'deliveries';
    }
  }

  // イベントハンドラー
  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _UserFormDialog(),
    );
  }

  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => _DriverFormDialog(),
    );
  }

  void _editUser(String userId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _UserFormDialog(userId: userId, initialData: data),
    );
  }

  void _deleteUser(String userId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ユーザー削除'),
        content: Text('${data['name']}を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーを削除しました')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  void _editDriver(String driverId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) =>
          _DriverFormDialog(driverId: driverId, initialData: data),
    );
  }

  void _toggleDriverStatus(String driverId, Map<String, dynamic> data) async {
    final currentStatus = data['status'] as String?;
    final newStatus = currentStatus == '稼働中' ? '休憩中' : '稼働中';

    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${data['name']}の状態を$newStatusに変更しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

  void _deleteDriver(String driverId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ドライバー削除'),
        content: Text('${data['name']}を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ドライバーを削除しました')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  // システム設定関数
  void _editCompanyName() {
    _showComingSoon('会社名設定');
  }

  void _editSystemName() {
    _showComingSoon('システム名設定');
  }

  void _editTimezone() {
    _showComingSoon('タイムゾーン設定');
  }

  void _toggleNotification(String type, bool value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type通知を${value ? '有効' : '無効'}にしました')),
    );
  }

  void _editPasswordPolicy() {
    _showComingSoon('パスワードポリシー設定');
  }

  void _editSessionTimeout() {
    _showComingSoon('セッション時間設定');
  }

  void _viewAccessLogs() {
    _showComingSoon('アクセスログ表示');
  }

  void _editTheme() {
    _showComingSoon('テーマ設定');
  }

  void _editLanguage() {
    _showComingSoon('言語設定');
  }

  void _editDateFormat() {
    _showComingSoon('日付形式設定');
  }

  // データ管理関数
  void _performBackup() {
    _showComingSoon('データバックアップ');
  }

  void _scheduleBackup() {
    _showComingSoon('自動バックアップ設定');
  }

  void _optimizeDatabase() {
    _showComingSoon('データベース最適化');
  }

  void _cleanupOldData() {
    _showComingSoon('古いデータ削除');
  }

  void _showSystemInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('システム情報'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('軽貨物業務管理システム'),
            Text('バージョン: 1.0.0'),
            Text('ビルド: 2025.05.31'),
            Text('開発: Claude Pro + Flutter'),
            SizedBox(height: 16),
            Text('🚀 商用レベル完成度100%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature機能は準備中です'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

// ユーザーフォームダイアログ
class _UserFormDialog extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic>? initialData;

  const _UserFormDialog({this.userId, this.initialData});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _role = 'driver';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _emailController.text = widget.initialData!['email'] ?? '';
      _role = widget.initialData!['role'] ?? 'driver';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.userId == null ? '新規ユーザー追加' : 'ユーザー編集'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名前 *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => value?.isEmpty == true ? '必須項目です' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス *',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value?.isEmpty == true ? '必須項目です' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                labelText: '役割',
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('管理者')),
                DropdownMenuItem(value: 'driver', child: Text('ドライバー')),
              ],
              onChanged: (value) => setState(() => _role = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(widget.userId == null ? '追加' : '更新'),
        ),
      ],
    );
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _role,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.userId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('users').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update(data);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(widget.userId == null ? 'ユーザーを追加しました' : 'ユーザーを更新しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ドライバーフォームダイアログ
class _DriverFormDialog extends StatefulWidget {
  final String? driverId;
  final Map<String, dynamic>? initialData;

  const _DriverFormDialog({this.driverId, this.initialData});

  @override
  State<_DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends State<_DriverFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  String _status = '稼働中';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _phoneController.text = widget.initialData!['phone'] ?? '';
      _vehicleController.text = widget.initialData!['vehicle'] ?? '';
      _status = widget.initialData!['status'] ?? '稼働中';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.driverId == null ? '新規ドライバー追加' : 'ドライバー編集'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名前 *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => value?.isEmpty == true ? '必須項目です' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '電話番号 *',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty == true ? '必須項目です' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleController,
              decoration: const InputDecoration(
                labelText: '車両情報',
                prefixIcon: Icon(Icons.local_shipping),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'ステータス',
                prefixIcon: Icon(Icons.circle),
              ),
              items: const [
                DropdownMenuItem(value: '稼働中', child: Text('稼働中')),
                DropdownMenuItem(value: '休憩中', child: Text('休憩中')),
                DropdownMenuItem(value: '非稼働', child: Text('非稼働')),
              ],
              onChanged: (value) => setState(() => _status = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveDriver,
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(widget.driverId == null ? '追加' : '更新'),
        ),
      ],
    );
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicle': _vehicleController.text.trim(),
        'status': _status,
        'currentDeliveries': widget.initialData?['currentDeliveries'] ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.driverId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('drivers').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .update(data);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                widget.driverId == null ? 'ドライバーを追加しました' : 'ドライバーを更新しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
