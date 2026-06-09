import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/svibe_models.dart';
import '../auth/auth_controller.dart';

final feedProvider = FutureProvider.autoDispose<List<VibeFeedItem>>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.token;
  if (token == null) {
    return [];
  }
  return ref.watch(apiClientProvider).feed(token);
});
