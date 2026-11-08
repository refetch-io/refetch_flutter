import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Submits stories through the app API (`/api/app/submit`). As on refetch.io,
/// a story is a link; an optional note becomes the first comment.
class SubmitRepository {
  SubmitRepository(this._api);

  final ApiClient _api;

  /// Returns the new story's id.
  Future<String> submit({
    required String title,
    required String url,
    String? comment,
  }) async {
    final data =
        await _api.post(
              '/api/app/submit',
              body: {
                'title': title,
                'url': url,
                if (comment != null && comment.isNotEmpty) 'comment': comment,
              },
            )
            as Map<String, dynamic>;
    return '${data['id']}';
  }
}

final submitRepositoryProvider = Provider<SubmitRepository>((ref) {
  return SubmitRepository(ref.watch(apiClientProvider));
});
