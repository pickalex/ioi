import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class PermissionUtils {
  /// 请求权限并在 Android 上显示延迟 300ms 的权限说明蒙层
  /// [permission] 需要申请的权限
  /// [description] 权限说明文字
  static Future<PermissionStatus> requestWithMask({
    required Permission permission,
    required String description,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    final results = await requestMultipleWithMask(
      permissions: [permission],
      description: description,
      delay: delay,
    );
    return results[permission] ?? PermissionStatus.denied;
  }

  /// 请求多个权限并在 Android 上显示延迟 300ms 的权限说明蒙层
  static Future<Map<Permission, PermissionStatus>> requestMultipleWithMask({
    required List<Permission> permissions,
    required String description,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    // iOS 不需要这个权限说明弹窗，直接请求
    if (!Platform.isAndroid) {
      return await permissions.request();
    }

    bool isRequestFinished = false;
    bool isDialogShowing = false;
    Timer? timer;

    // 延时执行显示蒙层
    timer = Timer(delay, () {
      if (!isRequestFinished) {
        isDialogShowing = true;
        _showPermissionMask(description);
      }
    });

    try {
      // 执行权限申请 (合并请求)
      final results = await permissions.request();
      return results;
    } finally {
      isRequestFinished = true;
      timer.cancel();
      if (isDialogShowing) {
        SmartDialog.dismiss(tag: 'permission_mask', force: true);
      }
    }
  }

  /// 显示权限说明蒙层 (顶部悬浮)
  static void _showPermissionMask(String description) {
    SmartDialog.show(
      tag: 'permission_mask',
      alignment: Alignment.topCenter,
      maskColor: Colors.black45,
      animationType: SmartAnimationType.fade,
      builder: (context) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '权限使用说明',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 常见权限定义 ---

  /// 相机权限请求
  static Future<PermissionStatus> requestCamera() {
    return requestWithMask(
      permission: Permission.camera,
      description: '我们将使用相机权限用于拍摄照片、扫描二维码以及进行视频通话。',
    );
  }

  /// 相机和麦克风权限请求 (常用于直播)
  static Future<bool> requestCameraAndMicrophone() async {
    final results = await requestMultipleWithMask(
      permissions: [Permission.camera, Permission.microphone],
      description: '我们将使用相机和麦克风权限用于视频通话和直播。',
    );
    return results[Permission.camera]?.isGranted == true &&
        results[Permission.microphone]?.isGranted == true;
  }

  /// 麦克风权限请求
  static Future<PermissionStatus> requestMicrophone() {
    return requestWithMask(
      permission: Permission.microphone,
      description: '我们将使用麦克风权限用于录制声音以及在视频通话中发送语音。',
    );
  }

  /// 存储权限请求 (Android 13 以下)
  static Future<PermissionStatus> requestStorage() {
    return requestWithMask(
      permission: Permission.storage,
      description: '我们将访问您的存储空间，以便保存和读取照片、文件。',
    );
  }

  /// 位置权限请求
  static Future<PermissionStatus> requestLocation() {
    return requestWithMask(
      permission: Permission.location,
      description: '我们将获取您的位置信息，以便为您提供周边的直播内容和推荐。',
    );
  }
}
