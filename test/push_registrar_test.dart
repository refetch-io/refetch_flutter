import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refetch/core/push/push_registrar.dart';
import 'package:refetch/core/push/push_target_store.dart';

class _MockAccount extends Mock implements Account {}

models.Target _target(String id) => models.Target(
  $id: id,
  $createdAt: '',
  $updatedAt: '',
  name: '',
  userId: 'u1',
  providerType: 'push',
  identifier: 'tok',
  expired: false,
);

void main() {
  late _MockAccount account;

  setUp(() => account = _MockAccount());

  test('first registration creates a target and stores its id', () async {
    final store = InMemoryPushTargetStore();
    when(
      () => account.createPushTarget(
        targetId: any(named: 'targetId'),
        identifier: any(named: 'identifier'),
        providerId: any(named: 'providerId'),
      ),
    ).thenAnswer((_) async => _target('t-new'));

    final registrar = PushRegistrar(account, store);
    final id = await registrar.register('fcm-token', providerId: 'fcm');

    expect(id, 't-new');
    expect(await store.read(), 't-new');
    verifyNever(() => account.updatePushTarget(
          targetId: any(named: 'targetId'),
          identifier: any(named: 'identifier'),
        ));
  });

  test('subsequent registration updates the existing target', () async {
    final store = InMemoryPushTargetStore('t-existing');
    when(
      () => account.updatePushTarget(
        targetId: 't-existing',
        identifier: any(named: 'identifier'),
      ),
    ).thenAnswer((_) async => _target('t-existing'));

    final registrar = PushRegistrar(account, store);
    final id = await registrar.register('refreshed-token');

    expect(id, 't-existing');
    verifyNever(() => account.createPushTarget(
          targetId: any(named: 'targetId'),
          identifier: any(named: 'identifier'),
          providerId: any(named: 'providerId'),
        ));
  });

  test('empty token is a no-op', () async {
    final store = InMemoryPushTargetStore();
    final registrar = PushRegistrar(account, store);
    expect(await registrar.register(''), isNull);
    verifyZeroInteractions(account);
  });

  test('a stale stored id is cleared on AppwriteException', () async {
    final store = InMemoryPushTargetStore('t-stale');
    when(
      () => account.updatePushTarget(
        targetId: any(named: 'targetId'),
        identifier: any(named: 'identifier'),
      ),
    ).thenThrow(AppwriteException('not found', 404));

    final registrar = PushRegistrar(account, store);
    final id = await registrar.register('token');

    expect(id, isNull);
    expect(await store.read(), isNull);
  });

  test('a target bound to another provider is replaced, not updated', () async {
    // What shipped in build 1: a target created before the APNS provider
    // existed, so it carries no provider and delivers through the wrong one.
    final store = InMemoryPushTargetStore('t-no-provider');
    when(() => account.deletePushTarget(targetId: 't-no-provider'))
        .thenAnswer((_) async => {});
    when(
      () => account.createPushTarget(
        targetId: any(named: 'targetId'),
        identifier: any(named: 'identifier'),
        providerId: 'apns',
      ),
    ).thenAnswer((_) async => _target('t-apns'));

    final registrar = PushRegistrar(account, store);
    final id = await registrar.register('apns-token', providerId: 'apns');

    expect(id, 't-apns');
    expect(await store.read(), 't-apns');
    expect(await store.readProviderId(), 'apns');
    verify(() => account.deletePushTarget(targetId: 't-no-provider')).called(1);
    verifyNever(() => account.updatePushTarget(
          targetId: any(named: 'targetId'),
          identifier: any(named: 'identifier'),
        ));
  });

  test('a target on the same provider is still updated in place', () async {
    final store = InMemoryPushTargetStore('t-fcm', 'fcm');
    when(
      () => account.updatePushTarget(
        targetId: 't-fcm',
        identifier: any(named: 'identifier'),
      ),
    ).thenAnswer((_) async => _target('t-fcm'));

    final registrar = PushRegistrar(account, store);
    final id = await registrar.register('refreshed', providerId: 'fcm');

    expect(id, 't-fcm');
    verifyNever(() => account.deletePushTarget(targetId: any(named: 'targetId')));
  });

  test('unregister deletes the target and clears the store', () async {
    final store = InMemoryPushTargetStore('t-1');
    when(() => account.deletePushTarget(targetId: 't-1'))
        .thenAnswer((_) async => {});

    final registrar = PushRegistrar(account, store);
    await registrar.unregister();

    expect(await store.read(), isNull);
    verify(() => account.deletePushTarget(targetId: 't-1')).called(1);
  });

  test('unregister with no stored target does nothing', () async {
    final store = InMemoryPushTargetStore();
    final registrar = PushRegistrar(account, store);
    await registrar.unregister();
    verifyZeroInteractions(account);
  });
}
