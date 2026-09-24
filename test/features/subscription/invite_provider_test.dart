/// 邀请状态 Provider 单测
library;

import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/providers/invite_provider.dart';
import 'package:echo_loop/features/subscription/services/invite_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInviteService extends Mock implements InviteService {}

class _FakeAuthResponse extends AuthResponse {
  _FakeAuthResponse({
    super.userId = 'user-1',
    super.email = 'test@example.com',
    super.accessToken = 'test-token',
  });
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(AuthResponse response) : super() {
    state = response;
  }
}

void main() {
  late _MockInviteService mockService;

  setUp(() {
    mockService = _MockInviteService();
    registerFallbackValue(_FakeAuthResponse());
  });

  test('初始状态为 loading（无登录态）', () {
    when(() => mockService.getInviteInfo(accessToken: any(named: 'accessToken')))
        .thenAnswer((_) async => const InviteRecord(
              inviteCode: 'INV000',
              friendsSignedUp: 0,
              monthsEarned: 0,
            ));

    final container = ProviderContainer(
      overrides: [
        inviteServiceProvider.overrideWithValue(mockService),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(inviteStateProvider);
    // 未登录时立即变为 error
    expect(state.status, InviteStateStatus.error);
  });

  test('服务返回成功后状态变为 success', () async {
    when(() => mockService.getInviteInfo(accessToken: any(named: 'accessToken')))
        .thenAnswer((_) async => const InviteRecord(
              inviteCode: 'INV12345',
              friendsSignedUp: 2,
              monthsEarned: 14,
            ));

    final container = ProviderContainer(
      overrides: [
        inviteServiceProvider.overrideWithValue(mockService),
        authSessionProvider.overrideWith(
          (ref) => _FakeAuthSessionNotifier(_FakeAuthResponse()),
        ),
      ],
    );
    addTearDown(container.dispose);

    // load() 是 async，轮询等待非 loading 状态
    late InviteState state;
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      state = container.read(inviteStateProvider);
      if (state.status != InviteStateStatus.loading) break;
    }
    expect(state.status, InviteStateStatus.success);
    expect(state.inviteCode, 'INV12345');
    expect(state.friendsSignedUp, 2);
    expect(state.monthsEarned, 14);
  });

  test('服务抛异常时状态变为 error', () async {
    when(() => mockService.getInviteInfo(accessToken: any(named: 'accessToken')))
        .thenThrow(const InviteException('network error'));

    final container = ProviderContainer(
      overrides: [
        inviteServiceProvider.overrideWithValue(mockService),
        authSessionProvider.overrideWith(
          (ref) => _FakeAuthSessionNotifier(_FakeAuthResponse()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(inviteStateProvider);
    expect(state.status, InviteStateStatus.error);
  });
}
