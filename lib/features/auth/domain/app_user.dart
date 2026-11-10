import 'package:appwrite/models.dart' as models;

/// The signed-in user, projected from the Appwrite account model.
class AppUser {
  const AppUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  /// Display name, falling back to the email local-part when unset.
  String get displayName =>
      name.trim().isNotEmpty ? name : email.split('@').first;

  factory AppUser.fromAccount(models.User account) {
    return AppUser(
      id: account.$id,
      name: account.name,
      email: account.email,
    );
  }
}
