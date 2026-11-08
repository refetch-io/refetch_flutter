import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// The shared Appwrite [Client], configured for the refetch project.
final appwriteClientProvider = Provider<Client>((ref) {
  return Client()
      .setEndpoint(AppConfig.appwriteEndpoint)
      .setProject(AppConfig.appwriteProjectId);
});

/// Appwrite [Account] service — used for authentication and JWT minting.
final accountProvider = Provider<Account>((ref) {
  return Account(ref.watch(appwriteClientProvider));
});

/// Appwrite [TablesDB] service — public reads of posts and comments.
final tablesDbProvider = Provider<TablesDB>((ref) {
  return TablesDB(ref.watch(appwriteClientProvider));
});
