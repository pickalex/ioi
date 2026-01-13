import 'package:agora_rtc_engine_example/components/config_override.dart';

/// Get your own App ID at https://dashboard.agora.io/
String get appId {
  // You can directly edit this code to return the appId you want.
  // return ExampleConfigOverride().getAppId();
  return "68d51391562342d1a669b890a019ef2c"; // <--- 【请务必改成你的真实 App ID】
}

/// Please refer to https://docs.agora.io/en/Agora%20Platform/token
String get token {
  // You can directly edit this code to return the token you want.
  // return ExampleConfigOverride().getToken();
  return "007eJxTYMjSmXThRL4G361HTjterdBcuObh5lVvLIvNM40Xi/08rxCswGBmkWJqaGxpaGpmZGxilGKYaGZmmWRhaZBoYGiZmmaUrHI/JLMhkJHhJM9mJkYGRgYWIAbxmcAkM5hkgbINjYwZGAChxiES"; // <--- 【如果有 Token 请填这里，没有则留空】
}

/// Your channel ID
String get channelId {
  // You can directly edit this code to return the channel ID you want.
  // return ExampleConfigOverride().getChannelId();
  return "123"; // <--- 频道名
}

/// Your int user ID
const int uid = 0;

/// Your user ID for the screen sharing
const int screenSharingUid = 10;

/// Your string user ID
const String stringUid = '0';
