import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/feed/domain/post.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/analytics_service.dart';

/// Opens the system share sheet with the story's refetch.io thread link,
/// and records whether the person went through with it.
Future<void> shareStory(
  BuildContext context,
  WidgetRef ref,
  Post post, {
  required String source,
}) async {
  // iPad and macOS anchor the sheet to the button that opened it.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  final analytics = ref.read(analyticsProvider);

  final result = await SharePlus.instance.share(
    ShareParams(
      uri: Uri.parse(post.threadUrl),
      subject: post.title,
      title: post.title,
      sharePositionOrigin: origin,
    ),
  );
  analytics.track(
    AnalyticsEvents.storyShared,
    props: {
      'post_id': post.id,
      'source': source,
      'method': 'native',
      'result': result.status.name,
    },
  );
}
