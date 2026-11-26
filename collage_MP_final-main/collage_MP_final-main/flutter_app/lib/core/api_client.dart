import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

final apiProvider = Provider<Dio>((ref) {
  final base = ref.watch(baseUrlProvider);
  return Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12)));
});
