import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceMonitor extends StatefulWidget {
  const PerformanceMonitor({Key? key}) : super(key: key);

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  final List<PerformanceMetric> _metrics = [];
  bool _isMonitoring = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パフォーマンス監視'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _toggleMonitoring,
            icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
            tooltip: _isMonitoring ? '監視停止' : '監視開始',
          ),
          IconButton(
            onPressed: _clearMetrics,
            icon: const Icon(Icons.clear_all),
            tooltip: 'クリア',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonitoringStatus(),
          _buildPerformanceTests(),
          _buildMetricsHeader(),
          Expanded(child: _buildMetricsList()),
        ],
      ),
    );
  }

  Widget _buildMonitoringStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _isMonitoring ? Colors.green.shade100 : Colors.grey.shade100,
      child: Row(
        children: [
          Icon(
            _isMonitoring ? Icons.monitor : Icons.monitor_outlined,
            color: _isMonitoring ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            _isMonitoring ? '監視中...' : '監視停止中',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isMonitoring ? Colors.green : Colors.grey,
            ),
          ),
          const Spacer(),
          Text('記録数: ${_metrics.length}'),
        ],
      ),
    );
  }

  Widget _buildPerformanceTests() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'パフォーマンステスト',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _testFirestoreRead(),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Firestore読み込み'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              ElevatedButton.icon(
                onPressed: () => _testFirestoreWrite(),
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Firestore書き込み'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              ElevatedButton.icon(
                onPressed: () => _testComplexQuery(),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('複雑クエリ'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              ElevatedButton.icon(
                onPressed: () => _testBatchOperation(),
                icon: const Icon(Icons.batch_prediction, size: 16),
                label: const Text('バッチ処理'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsHeader() {
    if (_metrics.isEmpty) return const SizedBox();

    final avgResponseTime = _metrics
        .map((m) => m.responseTime)
        .reduce((a, b) => a + b) / _metrics.length;

    final successRate = _metrics.where((m) => m.isSuccess).length / _metrics.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              '平均応答時間',
              '${avgResponseTime.toStringAsFixed(2)}ms',
              Icons.timer,
              _getResponseTimeColor(avgResponseTime),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              '成功率',
              '${(successRate * 100).toStringAsFixed(1)}%',
              Icons.check_circle,
              _getSuccessRateColor(successRate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsList() {
    if (_metrics.isEmpty) {
      return const Center(
        child: Text('パフォーマンステストを実行してください'),
      );
    }

    return ListView.builder(
      itemCount: _metrics.length,
      itemBuilder: (context, index) {
        final metric = _metrics[_metrics.length - 1 - index]; // 新しい順
        return _buildMetricCard(metric);
      },
    );
  }

  Widget _buildMetricCard(PerformanceMetric metric) {
    final responseTimeColor = _getResponseTimeColor(metric.responseTime);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          metric.isSuccess ? Icons.check_circle : Icons.error,
          color: metric.isSuccess ? Colors.green : Colors.red,
        ),
        title: Row(
          children: [
            Expanded(child: Text(metric.operation)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: responseTimeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${metric.responseTime.toStringAsFixed(0)}ms',
                style: TextStyle(
                  color: responseTimeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metric.details.isNotEmpty) Text(metric.details),
            Text(
              _formatTimestamp(metric.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: metric.isSuccess 
            ? null 
            : const Icon(Icons.warning, color: Colors.orange, size: 16),
      ),
    );
  }

  Color _getResponseTimeColor(double responseTime) {
    if (responseTime < 100) return Colors.green;
    if (responseTime < 500) return Colors.orange;
    return Colors.red;
  }

  Color _getSuccessRateColor(double successRate) {
    if (successRate >= 0.95) return Colors.green;
    if (successRate >= 0.8) return Colors.orange;
    return Colors.red;
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
    });
  }

  void _clearMetrics() {
    setState(() {
      _metrics.clear();
    });
  }

  void _addMetric(PerformanceMetric metric) {
    if (mounted) {
      setState(() {
        _metrics.add(metric);
        // 最新100件まで保持
        if (_metrics.length > 100) {
          _metrics.removeAt(0);
        }
      });
    }
  }

  Future<void> _testFirestoreRead() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .limit(20)
          .get();
      
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: 'Firestore読み込み (20件)',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: true,
        details: '配送案件を20件取得',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: 'Firestore読み込み (失敗)',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: false,
        details: 'エラー: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _testFirestoreWrite() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await FirebaseFirestore.instance
          .collection('performance_test')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'test': 'パフォーマンステスト',
        'value': DateTime.now().millisecondsSinceEpoch,
      });
      
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: 'Firestore書き込み',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: true,
        details: 'テストデータを1件追加',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: 'Firestore書き込み (失敗)',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: false,
        details: 'エラー: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _testComplexQuery() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .where('status', isEqualTo: '完了')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: '複雑クエリ',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: true,
        details: '完了済み配送案件を50件取得',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: '複雑クエリ (失敗)',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: false,
        details: 'エラー: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _testBatchOperation() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (int i = 0; i < 10; i++) {
        final ref = FirebaseFirestore.instance
            .collection('performance_test')
            .doc();
        batch.set(ref, {
          'batchTest': true,
          'index': i,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: 'バッチ処理',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: true,
        details: '10件のドキュメントをバッチ作成',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      stopwatch.stop();
      _addMetric(PerformanceMetric(
        operation: 'バッチ処理 (失敗)',
        responseTime: stopwatch.elapsedMilliseconds.toDouble(),
        isSuccess: false,
        details: 'エラー: $e',
        timestamp: DateTime.now(),
      ));
    }
  }
}

class PerformanceMetric {
  final String operation;
  final double responseTime;
  final bool isSuccess;
  final String details;
  final DateTime timestamp;

  PerformanceMetric({
    required this.operation,
    required this.responseTime,
    required this.isSuccess,
    required this.details,
    required this.timestamp,
  });
}