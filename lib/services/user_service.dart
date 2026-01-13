import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'http_service.dart';

/// 用户服务 - 管理本地用户数据
class UserService {
  static const String _userKey = 'current_user';
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  User? _currentUser;
  SharedPreferences? _prefs;

  /// 当前登录用户
  User? get currentUser => _currentUser;

  /// 是否已登录
  bool get isLoggedIn => _currentUser != null;

  /// 初始化服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadUser();
  }

  /// 加载本地用户
  Future<void> _loadUser() async {
    final userJson = _prefs?.getString(_userKey);
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userJson));
      } catch (e) {
        _currentUser = null;
      }
    }
  }

  /// 注册新用户
  Future<User> register(String username) async {
    final user = User(
      id: _generateUserId(),
      username: username,
      createdAt: DateTime.now(),
    );
    await _saveUser(user);
    return user;
  }

  /// 登录（通过 userId）
  Future<bool> login(String userId, String username) async {
    final user = User(
      id: userId,
      username: username,
      createdAt: DateTime.now(),
    );
    await _saveUser(user);
    return true;
  }

  /// 登出
  Future<void> logout() async {
    _currentUser = null;
    await _prefs?.remove(_userKey);
  }

  
  Future<void> _saveUser(User user) async {
    _currentUser = user;
    await _prefs?.setString(_userKey, jsonEncode(user.toJson()));
  }

  String _generateUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'user_$timestamp$random';
  }

  // region Token Management
  static const String _tokenKey = 'auth_token';

  /// 获取保存的 Token
  Future<String?> getToken() async {
    // 确保 prefs 已初始化
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs?.getString(_tokenKey);
  }

  /// 保存 Token
  Future<void> saveToken(String token) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_tokenKey, token);
    // Token 变化，清除缓存
    httpService.clearAuthCache();
  }

  /// 清除 Token
  Future<void> clearToken() async {
    await _prefs?.remove(_tokenKey);
    // Token 变化，清除缓存
    httpService.clearAuthCache();
  }

  // endregion
}

/// 全局 UserService 实例
final userService = UserService();
