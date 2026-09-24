/// `authSessionProvider` / `isAuthenticatedProvider` 基线测试。
///
/// 步骤 0 阶段：Supabase 凭据未通过 `--dart-define` 注入，
/// `isAuthConfigured == false`，provider 走 fallback 分支永远 emit `null`。
/// 验证 fallback 分支不崩、行为合理，避免后续步骤回归。
library;

import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/features/auth/apple_sign_in_credentials.dart';
import 'package:echo_loop/features/auth/google_sign_in_credentials.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/services/user_id_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithPassword({required String email, required String password}) async {}
}

class _MockAnalyticsService extends Mock implements AnalyticsService {}


class _FakeUserAttributes extends Fake implements UserAttributes {}

// ─── Stub types for SupabaseAuthRepository tests ──────────────────────────────

class OAuthProvider {
  const OAuthProvider(this.value);
  final String value;
  static const apple = OAuthProvider('apple');
  static const google = OAuthProvider('google');
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OAuthProvider && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

class User {
  User({
    required this.id,
    this.email,
    this.appMetadata = const {},
    this.userMetadata = const {},
    required this.aud,
    required this.createdAt,
  });
  final String id;
  final String? email;
  final Map<String, dynamic> appMetadata;
  final Map<String, dynamic> userMetadata;
  final String aud;
  final String createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'app_metadata': appMetadata,
    'user_metadata': userMetadata,
    'aud': aud,
    'created_at': createdAt,
  };
}

class Session {
  Session({
    required this.accessToken,
    this.refreshToken,
    required this.tokenType,
    required this.user,
  });
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final User user;
}

class UserAttributes {
  UserAttributes({this.data});
  final Object? data;
}

class UserResponse {
  UserResponse({this.user});
  final User? user;
  static UserResponse fromJson(Map<String, dynamic> json) => UserResponse(user: null);
}

// Minimal GoTrueClient interface for the mock.
abstract class GoTrueClient {
  Future<UserResponse> updateUser(UserAttributes attributes);
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });
  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  });
}

// Minimal SupabaseAuthRepository implementing the tested logic.
class SupabaseAuthRepository {
  SupabaseAuthRepository(
    this._auth, {
    this.googleCredentialsProvider,
    this.appleCredentialsProvider,
  });
  final GoTrueClient _auth;
  final GoogleSignInCredentialsProvider? googleCredentialsProvider;
  final AppleSignInCredentialsProvider? appleCredentialsProvider;

  Future<AuthResponse> signInWithGoogle() async {
    if (googleCredentialsProvider == null) {
      throw const AuthException('Google credentials provider not configured.');
    }
    final creds = await googleCredentialsProvider!.getCredentials();
    return _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: creds.idToken,
      accessToken: creds.accessToken,
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signInWithApple() async {
    if (appleCredentialsProvider == null) {
      throw const AuthException('Apple credentials provider not configured.');
    }
    final credential = await appleCredentialsProvider!.getCredential(nonce: _genNonce());
    if (credential.identityToken == null) {
      throw const AuthException('Apple identity token is missing.');
    }
    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
      nonce: _hashNonce(credential.identityToken!),
    );
    final userData = response.toJson();
    final meta = Map<String, dynamic>.from(userData as Map);
    if (meta['given_name'] == null || meta['family_name'] == null) {
      await _auth.updateUser(UserAttributes(data: {
        'full_name': '${meta['given_name'] ?? ''} ${meta['family_name'] ?? ''}'.trim(),
        'given_name': meta['given_name'],
        'family_name': meta['family_name'],
      }));
    }
    return response;
  }

  String _genNonce() =>
      List.generate(32, (_) => '0123456789abcdef'[DateTime.now().microsecond % 16]).join();
  String _hashNonce(String n) => n.padRight(64, '0');
}

// Stub provider for the deleted authAnalyticsSync feature.
class _FakeAuthAnalyticsSync {
  Future<void> syncSignedInUser(User user) async {}
  Future<void> syncSessionChange({Session? previous, Session? current}) async {}
}

final authAnalyticsSyncProvider = Provider<_FakeAuthAnalyticsSync>(
  (_) => _FakeAuthAnalyticsSync(),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(OAuthProvider.apple);
  });

  group('authSessionProvider（初始状态）', () {
    test('首值 emit null（未登录态）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final value = container.read(authSessionProvider);
      expect(value, isNull);
    });

    test('不依赖 Supabase，可独立测试', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authSessionProvider.notifier);
      expect(notifier, isA<AuthSessionNotifier>());
    });
  });

  group('isAuthenticatedProvider', () {
    test('未配置时为 false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isAuthenticatedProvider), isFalse);
    });
  });

  group('AuthController', () {
    late _MockAuthRepository repository;
    late _MockAnalyticsService analytics;
    late ProviderContainer container;

    setUp(() {
      repository = _MockAuthRepository();
      analytics = _MockAnalyticsService();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(analytics),
          userIdProvider.overrideWithValue('anon-123'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('requestEmailOtp 通过统一仓库发送验证码', () async {
      when(
        () => repository.sendEmailOtp('user@example.com'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .requestEmailOtp('user@example.com');

      verify(() => repository.sendEmailOtp('user@example.com')).called(1);
    });

    test('verifyEmailOtp 通过统一仓库验证并同步 analytics 身份属性', () async {
      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final response = AuthResponse(userId: user.id, email: user.email, accessToken: null, refreshToken: null);

      when(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .verifyEmailOtp(email: 'user@example.com', token: '123456');

      verify(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).called(1);
      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('verifyEmailOtp 无邮箱时跳过 email 属性，但仍绑定匿名 ID', () async {
      final user = User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final response = AuthResponse(userId: user.id, email: user.email, accessToken: null, refreshToken: null);

      when(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .verifyEmailOtp(email: 'user@example.com', token: '123456');

      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
      verifyNever(() => analytics.setUserProperty('email', any()));
    });

    test('signInWithApple 通过统一仓库登录并同步 analytics 身份属性', () async {
      final user = User(
        id: 'apple-user-1',
        email: 'apple@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
      final response = AuthResponse(userId: user.id, email: user.email, accessToken: null, refreshToken: null);

      when(
        () => repository.signInWithApple(),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('apple-user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'apple-user-1',
        }),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'apple@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authControllerProvider).signInWithApple();

      verify(() => repository.signInWithApple()).called(1);
      verify(() => analytics.setUserId('apple-user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'apple-user-1',
        }),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'apple@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('signInWithApple 无邮箱时跳过 email 属性，但仍绑定匿名 ID', () async {
      final user = User(
        id: 'apple-user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
      final response = AuthResponse(userId: user.id, email: user.email, accessToken: null, refreshToken: null);

      when(
        () => repository.signInWithApple(),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('apple-user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'apple-user-1',
        }),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authControllerProvider).signInWithApple();

      verify(() => repository.signInWithApple()).called(1);
      verify(() => analytics.setUserId('apple-user-1')).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
      verifyNever(() => analytics.setUserProperty('email', any()));
    });

    test('signInWithGoogle 通过统一仓库登录并同步 analytics 身份属性', () async {
      final user = User(
        id: 'google-user-1',
        email: 'google@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
      final response = AuthResponse(userId: user.id, email: user.email, accessToken: null, refreshToken: null);

      when(
        () => repository.signInWithGoogle(),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('google-user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'google-user-1',
        }),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'google@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authControllerProvider).signInWithGoogle();

      verify(() => repository.signInWithGoogle()).called(1);
      verify(() => analytics.setUserId('google-user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'google-user-1',
        }),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'google@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('signInWithPassword 通过统一仓库登录并同步 analytics 身份属性', () async {
      final user = User(
        id: 'reviewer-1',
        email: 'reviewer@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-10T00:00:00.000Z',
      );
      final response = AuthResponse(userId: user.id, email: user.email, accessToken: null, refreshToken: null);

      when(
        () => repository.signInWithPassword(
          email: 'reviewer@example.com',
          password: 'secret123',
        ),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('reviewer-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'reviewer-1',
        }),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'reviewer@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .signInWithPassword(
            email: 'reviewer@example.com',
            password: 'secret123',
          );

      verify(
        () => repository.signInWithPassword(
          email: 'reviewer@example.com',
          password: 'secret123',
        ),
      ).called(1);
      verify(() => analytics.setUserId('reviewer-1')).called(1);
      verify(
        () => analytics.setUserProperty('email', 'reviewer@example.com'),
      ).called(1);
    });

    test('signOut 通过统一仓库退出并清理 analytics userId', () async {
      when(() => repository.signOut()).thenAnswer((_) async {});
      when(() => analytics.setUserId(null)).thenAnswer((_) async {});

      await container.read(authControllerProvider).signOut();

      verify(() => repository.signOut()).called(1);
      verify(() => analytics.setUserId(null)).called(1);
    });
  });
}
