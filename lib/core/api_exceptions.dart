import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Сервер недоступен. Проверьте соединение и что PocketBase запущен.',
  ]);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  const ConflictException(super.message);
}

class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

ApiException mapHttpError(int status, dynamic body) {
  final message =
      (body is Map && body['message'] is String)
          ? body['message'] as String
          : null;

  Map<String, String> fieldErrors = const {};
  if (body is Map && body['data'] is Map) {
    final data = body['data'] as Map;
    fieldErrors = data.map((k, v) {
      if (v is Map && v['message'] != null) {
        return MapEntry('$k', '${v['message']}');
      }
      return MapEntry('$k', '$v');
    });
  }

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    400 when fieldErrors.isNotEmpty => ValidationException(
      message ?? 'Ошибка валидации',
      fieldErrors,
    ),
    422 => ValidationException(message ?? 'Ошибка валидации', fieldErrors),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;

  final status = e.response?.statusCode;
  if (status != null && e.response?.data != null) {
    return mapHttpError(status, e.response!.data);
  }

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType
        .receiveTimeout => const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. '
      'Убедитесь, что PocketBase запущен на порту 8090.',
    ),
    DioExceptionType.cancel => const NetworkException('Запрос отменён.'),
    _ => ServerException(e.message ?? 'Неизвестная ошибка сети.'),
  };
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  } on ApiException {
    rethrow;
  }
}
