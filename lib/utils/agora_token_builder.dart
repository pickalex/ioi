import 'package:agora_token_generator/agora_token_generator.dart';

/// AgoraTokenBuilder - 简化的 Token 生成器
class AgoraTokenBuilder {
  // 固定的 App 凭证
  static const String _appId = "68d51391562342d1a669b890a019ef2c";
  static const String _appCertificate = "e6e2a63ef34d461db0ab245be84a03a7";

  /// 生成 RTC Token（简化版）
  static String rtcToken(String channelName, int uid) {
    return RtcTokenBuilder.buildTokenWithUid(
      appId: _appId,
      appCertificate: _appCertificate,
      channelName: channelName,
      uid: uid,
      tokenExpireSeconds: 86400,
    );
  }

  /// 生成 RTM Token（简化版）
  static String rtmToken(String userId) {
    return RtmTokenBuilder.buildToken(
      appId: _appId,
      appCertificate: _appCertificate,
      userId: userId,
      tokenExpireSeconds: 86400,
    );
  }

  // 保留完整版方法以便需要时使用
  static String buildRtcToken({
    required String appId,
    required String appCertificate,
    required String channelName,
    required String uid,
    int role = 1,
    int privilegeTs = 0,
  }) {
    return RtcTokenBuilder.buildTokenWithUid(
      appId: appId,
      appCertificate: appCertificate,
      channelName: channelName,
      uid: int.tryParse(uid) ?? 0,
      tokenExpireSeconds: 86400,
    );
  }

  static String buildRtmToken({
    required String appId,
    required String appCertificate,
    required String userAccount,
  }) {
    return RtmTokenBuilder.buildToken(
      appId: appId,
      appCertificate: appCertificate,
      userId: userAccount,
      tokenExpireSeconds: 86400,
    );
  }
}
