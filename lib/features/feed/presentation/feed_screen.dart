import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/refetch_logo.dart';
import '../data/feed_repository.dart';
import 'feed_list.dart';

/// Home screen: the Refetch wordmark, the four feed tabs (Top / New / Show /
/// Mines), and actions for submitting and the account.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: FeedTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: const RefetchLogo(height: 24),
          actions: [
            IconButton(
              tooltip: 'Submit a story',
              icon: const Icon(LucideIcons.squarePen, size: 22),
              onPressed: () => context.push('/submit'),
            ),
            // Account works signed out too: it offers sign-in and holds the
            // analytics switch, which signed-out people need as well.
            IconButton(
              tooltip: 'Account',
              icon: const Icon(LucideIcons.circleUserRound, size: 22),
              onPressed: () => context.push('/profile'),
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [for (final tab in FeedTab.values) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [for (final tab in FeedTab.values) FeedList(tab: tab)],
        ),
      ),
    );
  }
}
