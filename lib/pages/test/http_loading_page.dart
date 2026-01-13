import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/http_service.dart';
import '../../services/dialog_service.dart';
import '../../widgets/ios_app_bar.dart';

class HttpLoadingPage extends StatelessWidget {
  const HttpLoadingPage({super.key});

  /// 模拟一个登录请求
  Future<void> _handleLogin(BuildContext context) async {
    // 使用 runWithLoading 包装异步请求
    final result = await DialogService.runWithLoading<ApiResult>(
      msg: '正在登录...',
      task: httpService.get(
        '/users/1', // 使用 jsonplaceholder 的测试接口
        parser: (json) => json,
      ),
    );

    if (result != null && result.success) {
      DialogService.showNotification('登录成功：${result.data['name']}');
    } else {
      DialogService.showNotification('登录失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IosAppBar(title: 'Http Loading Demo'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download),
              label: const Text('请求用户数据 (Http + Loading)'),
              onPressed: () => _handleLogin(context),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.notifications_none),
              label: const Text('单条模式通知 (替换式)'),
              onPressed: () {
                DialogService.showNotification(
                  '当前时间: ${DateTime.now().second}',
                  mode: NotificationMode.single,
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.style),
              label: const Text('自定义外观 Loading'),
              onPressed: () async {
                await DialogService.runWithLoading(
                  task: Future.delayed(const Duration(seconds: 2)),
                  builder: (context, msg) => Card(
                    color: Colors.blue.shade800,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            msg,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
