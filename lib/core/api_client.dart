import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';

typedef TokenProvider = String? Function();
typedef TokenRefresher = Future<String?> Function();

Dio buildDio({TokenProvider? tokenProvider, TokenRefresher? onUnauthorized}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Не перезаписывать явный Authorization (важно при login/register).
        final existing = options.headers['Authorization'];
        if (existing == null || '$existing'.isEmpty) {
          final token = tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = token;
          }
        }
        if (kDebugMode) {
          debugPrint('[API] ${options.method} ${options.uri}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (kDebugMode) {
          debugPrint('[API] ← $status ${response.requestOptions.uri}');
        }
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;
        if (status == 401 &&
            onUnauthorized != null &&
            !path.contains('/auth/')) {
          try {
            final newToken = await onUnauthorized();
            if (newToken != null) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = newToken;
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            }
          } catch (_) {
            // fall through
          }
        }
        return handler.next(error);
      },
    ),
  );

  dio.interceptors.add(RetryInterceptor(dio));
  return dio;
}

class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio);
  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final method = err.requestOptions.method.toUpperCase();
    if (method != 'GET') {
      return handler.next(err);
    }
    final extra = err.requestOptions.extra;
    final attempt = (extra['retry_attempt'] as int?) ?? 0;
    if (attempt >= 3) {
      return handler.next(err);
    }
    if (err.type != DioExceptionType.connectionError &&
        err.type != DioExceptionType.connectionTimeout &&
        err.type != DioExceptionType.receiveTimeout) {
      return handler.next(err);
    }
    await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    final opts = err.requestOptions;
    opts.extra['retry_attempt'] = attempt + 1;
    try {
      final response = await _dio.fetch(opts);
      return handler.resolve(response);
    } catch (e) {
      if (e is DioException) return handler.next(e);
      return handler.next(err);
    }
  }
}
