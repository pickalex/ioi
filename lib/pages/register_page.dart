import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import '../services/user_service.dart';

/// 注册页面
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _selectedTestId;

  // 预设测试用户 ID（方便两台手机互加）
  static const _testUserIds = {'userA': '测试用户A', 'userB': '测试用户B'};

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      SmartDialog.showToast('请输入用户名');
      return;
    }
    if (username.length < 2) {
      SmartDialog.showToast('用户名至少2个字符');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 如果选择了测试 ID，使用固定 ID
      final userId =
          _selectedTestId ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      await userService.login(userId, username);
      SmartDialog.showToast('注册成功！ID: $userId');
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      SmartDialog.showToast('注册失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                '创建账号',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '开始你的直播之旅',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Test User ID Selector
              Text(
                '选择测试 ID（用于两台设备互加好友）',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: _testUserIds.entries.map((entry) {
                  final isSelected = _selectedTestId == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTestId = selected ? entry.key : null;
                        if (selected) {
                          _usernameController.text = entry.value;
                        }
                      });
                    },
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Username Input
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '用户名',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Register Button
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CupertinoActivityIndicator(color: Colors.white),
                      )
                    : const Text(
                        '注册',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              // Login Link
              TextButton(
                onPressed: () => context.push('/login'),
                child: Text(
                  '已有账号？登录',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
