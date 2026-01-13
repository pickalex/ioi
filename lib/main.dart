import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:live_app/l10n/app_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'router.dart';
import 'services/http_service.dart';
import 'services/user_service.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'database/database_helper.dart';
import 'bloc/favorites/favorites_bloc.dart';
import 'bloc/favorites/favorites_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize DB
  await DatabaseHelper.instance.database;

  // 初始化服务
  await userService.init();

  // _setupOrientationListener(router);

  // 配置 HTTP 服务（使用公开测试 API）
  httpService.setBaseUrl('https://jsonplaceholder.typicode.com');
  httpService.setTokenProvider(userService.getToken);

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              FavoritesBloc(DatabaseHelper.instance)..add(LoadFavorites()),
        ),
      ],
      child: const ProviderScope(child: MyApp()),
    ),
  );
}

// 全局 Locale 通知器
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('zh'));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Design size based on iPhone X standard (375 x 812)
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: appLocale,
          builder: (context, locale, child) {
            return MediaQuery.withNoTextScaling(
              child: MaterialApp.router(
                title: 'Agora Live',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blueAccent,
                  ),
                  useMaterial3: true,
                ),

                routerConfig: router,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: FlutterSmartDialog.init(),
              ),
            );
          },
        );
      },
    );
  }
}
