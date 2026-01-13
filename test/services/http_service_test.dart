import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_app/services/http_service.dart';

void main() {
  late HttpService httpService;

  setUp(() {
    httpService = HttpService();
    // Clear interceptors before each test to ensure clean state
    httpService.dio.interceptors.clear();
  });

  group('HttpService Retry Logic', () {
    test('Should retry specified number of times on failure', () async {
      int requestCount = 0;

      // Add a RetryInterceptor for testing
      // Note: We need to ensure we don't effectively duplicate the one in the service constructor
      // but since we clear interceptors in setUp, we need to re-add it if we want to test it.
      // However, HttpService constructor adds one.
      // Let's re-add a custom one for testing with zero delay.
      httpService.dio.interceptors.add(
        RetryInterceptor(
          dio: httpService.dio,
          logPrint: print, // Debug logging
          retries: 2, // 2 retries + 1 initial = 3 total
          retryDelays: const [
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
          ],
        ),
      );

      // Mock Interceptor to simulate failure then success
      // IMPORTANT: Add this LAST so it runs internal logic before retry interceptor sees error?
      // No, RetryInterceptor catches the error from the next handler.
      // So the order depends on how we want to capture it.
      // Actually, we need to mock the *network* layer.
      // But we are using Dio's Interceptors mechanism to mock.
      // If we use http_mock_adapter it's easier, but here we use interceptors.
      httpService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requestCount++;
            // Add slight delay to simulate network
            await Future.delayed(const Duration(milliseconds: 10));
            if (requestCount <= 2) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                  error: 'Simulated Timeout',
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'code': 200, 'data': 'Success', 'message': 'OK'},
                  statusCode: 200,
                ),
              );
            }
          },
        ),
      );

      final result = await httpService.get(
        '/test-retry',
        parser: (json) => json as String,
      );

      expect(requestCount, 3);
      expect(result.success, true);
      expect(result.data, 'Success');
    });

    test('Should fail if retry count exceeded', () async {
      int requestCount = 0;

      httpService.dio.interceptors.add(
        RetryInterceptor(
          dio: httpService.dio,
          retries: 2,
          retryDelays: const [Duration.zero, Duration.zero],
        ),
      );

      httpService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            final error = DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
              error: 'Simulated Timeout',
            );
            handler.reject(error);
          },
        ),
      );

      final result = await httpService.get(
        '/test-retry-fail',
        parser: (json) => json,
      );

      expect(requestCount, 3);
      expect(result.success, false);
      expect(result.errorMessage, contains('连接超时'));
    });

    test('Should not retry when disableRetry is true', () async {
      int requestCount = 0;

      httpService.dio.interceptors.add(
        RetryInterceptor(
          dio: httpService.dio,
          retries: 2,
          retryDelays: const [Duration.zero, Duration.zero],
        ),
      );

      httpService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            final error = DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
              error: 'Simulated Timeout',
            );
            handler.reject(error);
          },
        ),
      );

      final options = Options()..disableRetry = true;
      final result = await httpService.get(
        '/test-no-retry',
        parser: (json) => json,
        options: options,
      );

      expect(requestCount, 1);
      expect(result.success, false);
      expect(result.errorMessage, contains('连接超时'));
    });
  });

  group('HttpService Cancel Logic', () {
    test('Should cancel request when token is cancelled', () async {
      final cancelToken = CancelToken();

      // Mock Interceptor to simulate delay
      httpService.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // Wait a bit to allow cancellation to happen
            await Future.delayed(const Duration(milliseconds: 100));
            // Check if cancelled before resolving (Dio does this internally but mocking skips it sometimes)
            if (options.cancelToken?.isCancelled ?? false) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'code': 200, 'data': 'Should Not Reach Here'},
                  statusCode: 200,
                ),
              );
            }
          },
        ),
      );

      // Trigger cancel after a short delay
      Future.delayed(const Duration(milliseconds: 10), () {
        cancelToken.cancel('User cancelled');
      });

      final result = await httpService.get(
        '/test-cancel',
        parser: (json) => json,
        cancelToken: cancelToken,
      );

      expect(result.success, false);
      // Your _getErrorMessage returns "请求已取消" for DioExceptionType.cancel
      expect(result.errorMessage, contains('已取消'));
    });
  });
}
