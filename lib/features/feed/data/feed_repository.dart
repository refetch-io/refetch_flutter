import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appwrite/appwrite_providers.dart';
import '../../../core/config/app_config.dart';
import '../domain/post.dart';

/// The four feed views, matching the web app's tabs.
enum FeedTab {
  top('Top'),
  latest('New'),
  show('Show'),
  mines('Mines');

  const FeedTab(this.label);

  /// Title shown in the tab bar.
  final String label;

  /// Whether this tab requires an authenticated user.
  bool get requiresAuth => this == FeedTab.mines;

  /// Name used in analytics events.
  String get analyticsName => switch (this) {
    FeedTab.top => 'top',
    FeedTab.latest => 'new',
    FeedTab.show => 'show',
    FeedTab.mines => 'mines',
  };
}

/// Quality gates the web applies to the front page (`posts.server.ts`).
const _maxSpamScore = 70;
const _minRelevancyScore = 30;
const _frontPageWindow = Duration(hours: 24);

/// The TablesDB queries for one feed page, mirroring the web's `listFeed`
/// and `listUserPosts`. Pure so it can be tested.
List<String> feedQueries(
  FeedTab tab, {
  required int limit,
  required int offset,
  String? userId,
  DateTime? now,
}) {
  final page = [
    Query.limit(limit),
    Query.offset(offset),
    Query.select(Post.listFields),
  ];

  if (tab == FeedTab.mines) {
    return [
      Query.equal('userId', userId ?? ''),
      Query.orderDesc(r'$createdAt'),
      ...page,
    ];
  }

  final since = (now ?? DateTime.now()).toUtc().subtract(_frontPageWindow);
  return [
    Query.greaterThan(r'$createdAt', since.toIso8601String()),
    Query.lessThan('spamScore', _maxSpamScore),
    Query.greaterThan('relevancyScore', _minRelevancyScore),
    Query.equal('enhanced', true),
    if (tab == FeedTab.show) Query.equal('type', 'show'),
    if (tab == FeedTab.latest)
      Query.orderDesc(r'$createdAt')
    else ...[
      Query.orderDesc('score'),
      Query.orderDesc(r'$createdAt'),
    ],
    ...page,
  ];
}

/// Reads feed pages straight from the Appwrite posts table (public-read).
class FeedRepository {
  FeedRepository(this._tables);

  final TablesDB _tables;

  Future<List<Post>> fetch(
    FeedTab tab, {
    required int limit,
    required int offset,
    String? userId,
  }) async {
    if (tab == FeedTab.mines && userId == null) return const [];
    final result = await _tables.listRows(
      databaseId: AppConfig.databaseId,
      tableId: AppConfig.postsTableId,
      queries: feedQueries(tab, limit: limit, offset: offset, userId: userId),
      total: false,
    );
    return [for (final row in result.rows) Post.fromRow(row.data)];
  }

  /// One story with its summary columns, for the thread screen.
  Future<Post> get(String postId) async {
    final row = await _tables.getRow(
      databaseId: AppConfig.databaseId,
      tableId: AppConfig.postsTableId,
      rowId: postId,
    );
    return Post.fromRow(row.data);
  }
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(tablesDbProvider));
});
