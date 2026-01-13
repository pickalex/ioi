import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import 'package:isolate_manager/isolate_manager.dart';

enum AppEnvironment { dev, sit, pro }

enum ParseMode { main, compute, pool }

class EnvConfig {
  static const Map<AppEnvironment, String> baseUrls = {
    AppEnvironment.dev: 'https://dev-api.example.com',
    AppEnvironment.sit: 'https://sit-api.example.com',
    AppEnvironment.pro: 'https://api.example.com',
  };
}

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  ApiResult({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResult.success(T data) => ApiResult(success: true, data: data);

  factory ApiResult.failure(String message, {int? statusCode}) =>
      ApiResult(success: false, errorMessage: message, statusCode: statusCode);
}

class _ParseParams<T> {
  final dynamic data;
  final T Function(dynamic json) parser;

  _ParseParams(this.data, this.parser);
}

@pragma('vm:entry-point')
@isolateManagerWorker
T _httpIsoParser<T>(dynamic params) {
  final p = params as _ParseParams<T>;
  return p.parser(p.data);
}

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;

  late final Dio _dio;

  @visibleForTesting
  Dio get dio => _dio;

  Future<Map<String, String>> Function()? _authProvider;

  Map<String, String>? _cachedAuthHeaders;

  late final IsolateManager _isolateManager;

  HttpService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _isolateManager = IsolateManager.create(
      _httpIsoParser,
      concurrent: 3,
      workerName: 'HttpParser',
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_cachedAuthHeaders != null) {
            options.headers.addAll(_cachedAuthHeaders!);
          } else if (_authProvider != null) {
            final authHeaders = await _authProvider!();
            _cachedAuthHeaders = authHeaders;
            options.headers.addAll(authHeaders);
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          _handleError(error);
          return handler.next(error);
        },
      ),
    );

    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: debugPrint,
        retries: 1,
        retryDelays: const [Duration(seconds: 1)],
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          compact: false,
          maxWidth: 100,
        ),
      );
    }

    _externalDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  late final Dio _externalDio;
  Dio get externalDio => _externalDio;

  AppEnvironment _environment = AppEnvironment.dev;

  AppEnvironment get currentEnvironment => _environment;

  void setEnvironment(AppEnvironment env) {
    _environment = env;
    _dio.options.baseUrl = EnvConfig.baseUrls[env] ?? '';
    if (kDebugMode) {
      debugPrint('环境切换: ${env.name} -> ${_dio.options.baseUrl}');
    }
  }

  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  void setTokenProvider(
    Future<String?> Function() provider, {
    Map<String, String> Function(String token)? authHeaderBuilder,
  }) {
    _authProvider = () async {
      final token = await provider();
      if (token != null && token.isNotEmpty) {
        if (authHeaderBuilder != null) {
          return authHeaderBuilder(token);
        }
        return {'Authorization': 'Bearer $token'};
      }
      return const {};
    };
  }

  void clearAuthCache() {
    _cachedAuthHeaders = null;
  }

  final Set<String> _silentPaths = {};

  void addSilentPath(String path) => _silentPaths.add(path);

  void removeSilentPath(String path) => _silentPaths.remove(path);

  void setSilentPaths(List<String> paths) {
    _silentPaths.clear();
    _silentPaths.addAll(paths);
  }

  bool _isInSilentList(String path) {
    return _silentPaths.any((p) => path.contains(p));
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) parser,
    dynamic Function(dynamic response)? extractor,
    bool? silent,
    ParseMode mode = ParseMode.main,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final isSilent = silent ?? _isInSilentList(path);
    try {
      options ??= Options();
      options.sendTimeout ??= const Duration(seconds: 30);
      options.receiveTimeout ??= const Duration(seconds: 30);

      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      );

      return await _parseResponse(
        response,
        parser,
        extractor,
        silent: isSilent,
        mode: mode,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || e.type == DioExceptionType.badResponse) {
        return ApiResult.failure(
          _getErrorMessage(e),
          statusCode: e.response?.statusCode,
        );
      }
      return ApiResult.failure(_getErrorMessage(e));
    } catch (e) {
      return ApiResult.failure('未知错误: $e');
    }
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) parser,
    dynamic Function(dynamic response)? extractor,
    bool? silent,
    ParseMode mode = ParseMode.main,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final isSilent = silent ?? _isInSilentList(path);
    try {
      options ??= Options();
      options.sendTimeout ??= const Duration(seconds: 30);
      options.receiveTimeout ??= const Duration(seconds: 30);

      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      );
      return await _parseResponse(
        response,
        parser,
        extractor,
        silent: isSilent,
        mode: mode,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || e.type == DioExceptionType.badResponse) {
        return ApiResult.failure(
          _getErrorMessage(e),
          statusCode: e.response?.statusCode,
        );
      }
      return ApiResult.failure(_getErrorMessage(e));
    } catch (e) {
      return ApiResult.failure('未知错误: $e');
    }
  }

  Future<ApiResult<String>> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    int downloadStart = 0;
    File f = File(savePath);
    if (await f.exists()) {
      downloadStart = f.lengthSync();
    }

    RandomAccessFile? raf;

    try {
      var response = await _externalDio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: {"range": "bytes=$downloadStart-"},
        ),
        cancelToken: cancelToken,
      );

      File file = File(savePath);
      raf = file.openSync(mode: FileMode.append);

      int received = downloadStart;
      int total =
          int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '0',
          ) ??
          0;
      if (response.statusCode == 206) {
        total += downloadStart;
      } else {
        raf.setPositionSync(0); // overwrite
        raf.truncateSync(0);
        received = 0;
      }

      Stream<Uint8List> stream = response.data!.stream;
      await for (var chunk in stream) {
        raf.writeFromSync(chunk);
        received += chunk.length;
        onReceiveProgress?.call(received, total);
      }

      return ApiResult.success(savePath);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return ApiResult.failure("已取消下载");
      }
      return ApiResult.failure(_getErrorMessage(e));
    } catch (e) {
      return ApiResult.failure("下载出错: $e");
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  Future<ApiResult<T>> _parseResponse<T>(
    Response response,
    T Function(dynamic json) parser,
    dynamic Function(dynamic response)? extractor, {
    bool silent = false,
    ParseMode mode = ParseMode.main,
  }) async {
    final data = response.data;
    dynamic processedData = data;

    if (processedData is Map<String, dynamic>) {
      final hasCode =
          processedData.containsKey('code') ||
          processedData.containsKey('status');

      if (hasCode) {
        final rawCode = processedData['code'] ?? processedData['status'] ?? 0;
        final code = int.tryParse(rawCode.toString()) ?? 0;
        final message =
            processedData['message'] ??
            processedData['error'] ??
            processedData['msg'] ??
            '请求失败';

        if (code != 0 && code != 200) {
          if (!silent) SmartDialog.showToast(message.toString());
          return ApiResult.failure(message.toString(), statusCode: code);
        }

        if (extractor == null) {
          processedData = processedData['data'];
        }
      }
    }

    if (extractor != null) {
      try {
        processedData = extractor(processedData);
      } catch (e) {
        return ApiResult.failure('数据提取失败: $e');
      }
    }

    try {
      T parsed;
      switch (mode) {
        case ParseMode.pool:
          final result = await _isolateManager.compute(
            _ParseParams<T>(processedData, parser),
          );
          parsed = result;
          break;
        case ParseMode.compute:
          final result = await compute(
            _httpIsoParser,
            _ParseParams<T>(processedData, parser),
          );
          parsed = result as T;
          break;
        case ParseMode.main:
          parsed = parser(processedData);
          break;
      }
      return ApiResult.success(parsed);
    } catch (e) {
      return ApiResult.failure('数据解析失败: $e');
    }
  }

  void _handleError(DioException error) {
    final message = _getErrorMessage(error);
    SmartDialog.showToast(message);
  }

  String _getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.sendTimeout:
        return '发送超时';
      case DioExceptionType.receiveTimeout:
        return '接收超时';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          clearAuthCache();
          return '登录已过期';
        }
        if (statusCode == 403) return '没有权限';
        if (statusCode == 404) return '资源不存在';
        if (statusCode == 500) return '服务器错误';
        return '请求失败 ($statusCode)';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接失败';
      default:
        return '网络异常';
    }
  }

  static List<T> parseList<T>(
    dynamic json,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final list = json as List;
    return List<T>.generate(list.length, (index) {
      return fromJson(list[index] as Map<String, dynamic>);
    }, growable: false);
  }
}

final httpService = HttpService();
