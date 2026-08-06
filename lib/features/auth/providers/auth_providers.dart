library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/api_config.dart' as api_config;
import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';

// ─── Simple local types ───

class AuthResponse {
  final String? userId;
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final String? proxyToken; // NEW: for transcription API auth

  AuthResponse({this.userId, this.email, this.accessToken, this.refreshToken, this.proxyToken});

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'proxyToken': proxyToken,
  };

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    userId: json['userId']?.toString(),
    email: json['email']?.toString(),
    accessToken: json['accessToken']?.toString(),
    refreshToken: json['refreshToken']?.toString(),
    proxyToken: json['proxyToken']?.toString(),
  );

  AuthResponse copyWith({String? userId, String? email, String? accessToken, String? refreshToken, String? proxyToken}) {
    return AuthResponse(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      proxyToken: proxyToken ?? this.proxyToken,
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

abstract class AuthRepository {
  Future<void> sendEmailOtp(String email);
  Future<AuthResponse> verifyEmailOtp({required String email, required String token});
  Future<void> signOut();
}

// Self-hosted auth with proxy token support for transcription API
class SelfHostedAuthRepository implements AuthRepository {
  SelfHostedAuthRepository() : _apiDio = createBackendDio(baseUrl: api_config.apiBaseUrl);

  final Dio _apiDio;

  @override
  Future<void> sendEmailOtp(String email) async {
    try {
      AppLogger.log('Auth', 'Sending OTP to $email via ${api_config.apiBaseUrl}/api/auth/send-otp');
      await _apiDio.post('/api/auth/send-otp', data: {'email': email});
      AppLogger.log('Auth', 'Email OTP sent via self-hosted server');
    } catch (e) {
      AppLogger.log('Auth', 'sendEmailOtp error: $e');
      throw AuthException(e.toString());
    }
  }

  @override
  Future<AuthResponse> verifyEmailOtp({required String email, required String token}) async {
    try {
      AppLogger.log('Auth', 'Verifying OTP for $email');
      final response = await _apiDio.post('/api/auth/verify-otp', data: {
        'email': email,
        'token': token,
      });
      final data = response.data as Map<String, dynamic>;
      AppLogger.log('Auth', 'Self-hosted OTP verified, userId=${data['userId']}');
      return AuthResponse(
        userId: data['userId']?.toString(),
        email: email,
        accessToken: data['accessToken']?.toString(),
        refreshToken: data['refreshToken']?.toString(),
        proxyToken: null,
      );
    } on DioException catch (e) {
      throw AuthException(e.response?.data?['error']?.toString() ?? e.message ?? 'Unknown error');
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> signInWithApple() async {
    throw UnimplementedError('Apple Sign-In not yet implemented for self-hosted auth');
  }

  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Google Sign-In not yet implemented for self-hosted auth');
  }

  Future<void> signInWithPassword({required String email, required String password}) async {
    throw UnimplementedError('Password login not yet implemented for self-hosted auth');
  }

  @override
  Future<void> signOut() => Future.value();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => SelfHostedAuthRepository());

// ─── Session State ───

const _sessionKey = 'echo_loop_auth_session';

class AuthSessionNotifier extends StateNotifier<AuthResponse?> {
  AuthSessionNotifier() : super(null) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_sessionKey);
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        state = AuthResponse.fromJson(data);
      }
    } catch (e) {
      // Fail silently - session can be restored later
    }
  }

  Future<void> setSession(AuthResponse response) async {
    state = response;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, response.toJson().toString());
    } catch (e) {
      // Persist failure doesn't affect functionality
    }
  }

  Future<void> clearSession() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      // Fail silently
    }
  }
}

final authSessionProvider = StateNotifierProvider<AuthSessionNotifier, AuthResponse?>((ref) => AuthSessionNotifier());

final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider);
  return session != null && session.userId != null;
});

// ─── Auth Controller ───

class AuthController {
  AuthController(this._ref);
  final Ref _ref;
  AuthRepository get _repository => _ref.read(authRepositoryProvider);
  final Dio _apiDio = createBackendDio(baseUrl: api_config.apiBaseUrl);

  Future<void> requestEmailOtp(String email) => _repository.sendEmailOtp(email);

  Future<AuthResponse?> verifyEmailOtp({required String email, required String token}) async {
    try {
      final response = await _repository.verifyEmailOtp(email: email, token: token);
      if (response.userId != null) {
        AppLogger.log('Auth', 'User logged in: ${response.userId}');
        await _ref.read(authSessionProvider.notifier).setSession(response);
        // Fetch proxy token after successful login
        if (response.accessToken != null && response.accessToken!.isNotEmpty) {
          _fetchAndStoreProxyToken(response);
        }
      }
      return response;
    } on AuthException catch (e) {
      AppLogger.log('Auth', 'OTP verification failed: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.log('Auth', 'OTP verification failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    AppLogger.log('Auth', 'Signing out user');
    await _repository.signOut();
    await _ref.read(authSessionProvider.notifier).clearSession();
  }

  Future<void> signInWithApple() async {
    throw AuthException('Apple Sign-In not implemented for self-hosted auth');
  }

  Future<void> signInWithGoogle() async {
    throw AuthException('Google Sign-In not implemented for self-hosted auth');
  }

  Future<void> signInWithPassword({required String email, required String password}) async {
    throw AuthException('Password login not implemented for self-hosted auth');
  }

  // Fetch proxy token and update session state after login
  Future<void> _fetchAndStoreProxyToken(AuthResponse baseAuth) async {
    try {
      final proxyResp = await _apiDio.get(
        '/api/v2/user-audio/proxy-token',
        options: Options(headers: {'Authorization': 'Bearer ${baseAuth.accessToken!}'}),
      );
      final proxyToken = proxyResp.data['proxyToken'];
      if (proxyToken != null) {
        AppLogger.log('Auth', 'Proxy token fetched successfully, updating session');
        final updatedSession = baseAuth.copyWith(proxyToken: proxyToken);
        // Update both SharedPreferences and Riverpod state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, updatedSession.toJson().toString());
        await _ref.read(authSessionProvider.notifier).setSession(updatedSession);
      } else {
        AppLogger.log('Auth', 'Warning: proxy token response was empty');
      }
    } catch (e) {
      AppLogger.log('Auth', 'Warning: Could not fetch proxy token after login: $e');
      // Don't fail authentication if proxy token fetch fails
    }
  }
}

final authControllerProvider = Provider<AuthController>((ref) => AuthController(ref));
