import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/thread_repository.dart';

/// Loads a single thread (post + nested comments) by post id, with the
/// viewer's votes when signed in.
///
/// Invalidate `threadProvider(postId)` after a comment mutation to refresh.
final threadProvider = FutureProvider.family<ThreadData, String>((
  ref,
  postId,
) async {
  final signedIn = ref.watch(currentUserProvider) != null;
  return ref.read(threadRepositoryProvider).load(postId, signedIn: signedIn);
});
