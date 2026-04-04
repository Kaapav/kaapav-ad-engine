import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < maxRetries) {
        final delay = baseDelay * pow(2, retryCount).toInt();
        debugPrint(
            '🔄 Retry ${retryCount + 1}/$maxRetries after ${delay.inMilliseconds}ms — ${err.requestOptions.path}');

        await Future.delayed(delay);

        err.requestOptions.extra['retryCount'] = retryCount + 1;

        try {
          final response = await dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          if (e is DioException) {
            return super.onError(e, handler);
          }
        }
      } else {
        debugPrint('❌ Max retries reached for ${err.requestOptions.path}');
      }
    }

    super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    // Retry on timeout or server errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on 5xx server errors
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      return true;
    }

    // Retry on Meta rate limit (code 4, 32)
    if (statusCode == 400) {
      final data = err.response?.data;
      if (data is Map) {
        final errorCode = data['error']?['code'];
        if (errorCode == 4 || errorCode == 32) {
          return true;
        }
      }
    }

    return false;
  }
}