import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refetch/core/config/app_config.dart';
import 'package:refetch/core/push/appwrite_push_channel.dart';
import 'package:refetch/core/push/push_registrar.dart';
import 'package:refetch/core/push/push_topic.dart';
import 'package:refetch/core/push/topic_subscriptions.dart';

class _MockRegistrar extends Mock implements PushRegistrar {}

class _MockTopics extends Mock implements TopicSubscriptions {}

class _FakePush implements LivePush {
  /// Each subscribe call's topics (`null` = the user's own topic).
  final List<List<String>?> subscribed = [];
  final List<List<String>?> unsubscribed = [];
  Map<String, dynamic>? launchData;
  void Function(Map<String, dynamic>)? tapListener;
  int closes = 0;

  @override
  Future<VoidCallback> subscribe(List<String>? topics) async {
    subscribed.add(topics);
    return () => unsubscribed.add(topics);
  }

  @override
  Future<Map<String, dynamic>?> initialTapData() async => launchData;

  @override
  VoidCallback onTap(void Function(Map<String, dynamic> data) onTap) {
    tapListener = onTap;
    return () => tapListener = null;
  }

  @override
  void close() => closes++;
}

void main() {
  late _MockRegistrar registrar;
  late _MockTopics topics;
  late _FakePush push;
  late AppwritePushChannel channel;
  late List<String> opened;

  setUpAll(() => registerFallbackValue(PushTopic.digest));

  setUp(() {
    registrar = _MockRegistrar();
    topics = _MockTopics();
    push = _FakePush();
    opened = [];
    channel = AppwritePushChannel(
      registrar,
      topics,
      push: () => push,
      installId: () async => 'install-1',
    );
    when(
      () => registrar.register(any(), providerId: any(named: 'providerId')),
    ).thenAnswer((_) async => 'target-1');
    when(() => registrar.unregister()).thenAnswer((_) async {});
    when(() => topics.syncOnRegister(any())).thenAnswer((_) async {});
    when(() => topics.isEnabled(any())).thenAnswer((_) async => true);
  });

  test(
    'sign-in registers an Appwrite Push target with the install id',
    () async {
      await channel.onSignedIn();

      verify(
        () => registrar.register(
          'install-1',
          providerId: AppConfig.appwritePushProviderId,
        ),
      ).called(1);
      verify(() => topics.syncOnRegister('target-1')).called(1);
    },
  );

  test('sign-in subscribes the user topic and each enabled topic', () async {
    when(
      () => topics.isEnabled(PushTopic.replies),
    ).thenAnswer((_) async => false);

    await channel.onSignedIn();

    expect(push.subscribed, [
      null,
      [AppConfig.digestTopicId],
    ]);
  });

  test('without a target, only the user topic is subscribed', () async {
    when(
      () => registrar.register(any(), providerId: any(named: 'providerId')),
    ).thenAnswer((_) async => null);

    await channel.onSignedIn();

    expect(push.subscribed, [null]);
    verifyNever(() => topics.syncOnRegister(any()));
  });

  test('a second sign-in event does not subscribe twice', () async {
    await channel.onSignedIn();
    await channel.onSignedIn();

    verify(
      () => registrar.register(any(), providerId: any(named: 'providerId')),
    ).called(1);
    expect(push.subscribed.where((t) => t == null), hasLength(1));
  });

  test('a topic switched off ends its live subscription', () async {
    await channel.onSignedIn();
    await channel.applyTopic(PushTopic.digest, false);

    expect(push.unsubscribed, [
      [AppConfig.digestTopicId],
    ]);

    await channel.applyTopic(PushTopic.digest, true);
    expect(
      push.subscribed.where((t) => t?.first == AppConfig.digestTopicId),
      hasLength(2),
    );
  });

  test('topic switches before sign-in do nothing live', () async {
    await channel.applyTopic(PushTopic.digest, true);
    expect(push.subscribed, isEmpty);
  });

  test('sign-out closes Push and removes the target', () async {
    await channel.onSignedIn();
    await channel.onSignedOut();

    expect(push.closes, 1);
    verify(() => registrar.unregister()).called(1);

    // Signing in again starts over.
    await channel.onSignedIn();
    expect(push.subscribed.where((t) => t == null), hasLength(2));
  });

  test('the launch tap and later taps open the thread', () async {
    push.launchData = {'postId': 'p1', 'type': 'reply'};
    await channel.start(onOpenThread: opened.add);
    push.tapListener!({'postId': 'p2'});
    push.tapListener!({'type': 'digest'}); // no post: ignored

    expect(opened, ['p1', 'p2']);
  });
}
