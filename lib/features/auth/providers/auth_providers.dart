library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 条件导入：Web 平台使用真实 web.window.sessionStorage，非 Web 平台使用 stub。
// 避免 dart:js_interop 被带入 VM 测试（会因 platform 不支持而编译失败）。
import 'package:web/web.dart' as web
    if (dart.library.html) 'web_stub.dart';

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
  Future<AuthResponse> verifyEmailOtp({required String email, required String token, String? inviteCode});
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
  Future<void> signInWithPassword({required String email, required String password});
  Future<void> signOut();
}

// Self-hosted auth with proxy token support for transcription API
class SelfHostedAuthRepository implements AuthRepository {
  SelfHostedAuthRepository() : _apiDio = createBackendDio(baseUrl: api_config.apiBaseUrl);

  final Dio _apiDio;

  @override
  Future<void> sendEmailOtp(String email) async {
    try {
      // Log operation type only — never log PII (email) in plain text.
      AppLogger.log('Auth', 'Sending OTP to masked email (${email.length} chars)');
      await _apiDio.post('/api/auth/send-otp', data: {'email': email});
      AppLogger.log('Auth', 'Email OTP sent via self-hosted server');
    } catch (e) {
      AppLogger.log('Auth', 'sendEmailOtp error: $e');
      throw AuthException(e.toString());
    }
  }

  @override
  Future<AuthResponse> verifyEmailOtp({required String email, required String token, String? inviteCode}) async {
    try {
      // Log operation only — never log PII (email/userId) in plain text.
      AppLogger.log('Auth', 'Verifying OTP\$1');
      final reqBody = <String, dynamic>{'email': email, 'token': token};
      if (inviteCode != null && inviteCode.isNotEmpty) {
        reqBody['inviteCode'] = inviteCode.trim().toUpperCase();
      }
      final response = await _apiDio.post('/api/auth/verify-otp', data: reqBody);
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

  @override
  Future<void> signInWithApple() async {
    throw UnimplementedError('Apple Sign-In not yet implemented for self-hosted auth');
  }

  @override
  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Google Sign-In not yet implemented for self-hosted auth');
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    throw UnimplementedError('Password login not yet implemented for self-hosted auth');
  }

  @override
  Future<void> signOut() => Future.value();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => SelfHostedAuthRepository());

// ─── Session State ───

const _sessionKey = 'echo_loop_auth_session';
const _inviteCodeKey = 'echo_loop_invite_code';

/// Web 端 auth 数据读写（sessionStorage，tab 关闭自动清除），非 Web 端通过 SP 操作
class AuthSessionNotifier extends StateNotifier<AuthResponse?> {
  AuthSessionNotifier() : super(null) {
    _restoreSession();
  }

  /// 从存储中读取 session（Web 读 sessionStorage，移动端读 SP）
  Future<void> _restoreSession() async {
    try {
      final json = await _readSessionFromStorage();
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        state = AuthResponse.fromJson(data);
      }
    } catch (e) {
      AppLogger.log('Auth', 'restore session failed: $e');
    }
  }

  /// 写 session 到存储（Web 写 sessionStorage，移动端写 SP）
  Future<void> setSession(AuthResponse response) async {
    state = response;
    try {
      _writeSessionToStorage(response.toJson().toString());
    } catch (e) {
      AppLogger.log('Auth', 'persist session failed: $e');
    }
  }

  /// 清空 session（Web 清除 sessionStorage key，移动端 remove SP key）
  Future<void> clearSession() async {
    state = null;
    try {
      _clearSessionFromStorage();
    } catch (e) {
      AppLogger.log('Auth', 'clear session failed: $e');
    }
  }

  /// 读取 session JSON 字符串（Web 从 sessionStorage，非 Web 从 SP）
  static Future<String?> _readSessionFromStorage() async {
    if (kIsWeb) {
      try {
        return web.window.sessionStorage.getItem(_sessionKey);
      } catch (e) {
        AppLogger.log('Auth', '从 sessionStorage 读取 session 失败: $e');
        return null;
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_sessionKey);
      } catch (e) {
        return null;
      }
    }
  }

  /// 写入 session JSON 字符串到存储
  static void _writeSessionToStorage(String json) {
    if (kIsWeb) {
      try {
        web.window.sessionStorage.setItem(_sessionKey, json);
        AppLogger.log('Auth', 'session 写入 sessionStorage');
      } catch (e) {
        AppLogger.log('Auth', '写入 sessionStorage 失败: $e');
      }
    } else {
      try {
        SharedPreferences.getInstance().then((prefs) => prefs.setString(_sessionKey, json));
      } catch (e) {
        AppLogger.log('Auth', '写入 SP 失败: $e');
      }
    }
  }

  /// 清除存储中的 session
  static void _clearSessionFromStorage() {
    if (kIsWeb) {
      try {
        web.window.sessionStorage.removeItem(_sessionKey);
        AppLogger.log('Auth', 'session 从 sessionStorage 清除');
      } catch (e) {
        AppLogger.log('Auth', '清除 sessionStorage 失败: $e');
      }
    } else {
      try {
        SharedPreferences.getInstance().then((prefs) => prefs.remove(_sessionKey));
      } catch (e) {
        AppLogger.log('Auth', '清除 SP 失败: $e');
      }
    }
  }

  // ─── 邀请码读写（与 session 同平台策略）──────────────────────────────────────

  /// 读取待处理的邀请码（Web 读 sessionStorage，移动端读 SP）
  static Future<String?> _readInviteCode() async {
    if (kIsWeb) {
      try {
        return web.window.sessionStorage.getItem(_inviteCodeKey);
      } catch (e) {
        return null;
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_inviteCodeKey);
      } catch (_) {
        return null;
      }
    }
  }

  /// 写入待处理的邀请码
  static void _writeInviteCode(String code) {
    if (kIsWeb) {
      try {
        web.window.sessionStorage.setItem(_inviteCodeKey, code);
      } catch (e) {
        AppLogger.log('Auth', '写入邀请码到 sessionStorage 失败: $e');
      }
    } else {
      try {
        SharedPreferences.getInstance().then((prefs) => prefs.setString(_inviteCodeKey, code));
      } catch (e) {
        AppLogger.log('Auth', '写入邀请码到 SharedPreferences 失败: $e');
      }
    }
  }

  /// 清除待处理的邀请码
  static Future<void> _clearInviteCode() async {
    if (kIsWeb) {
      try {
        web.window.sessionStorage.removeItem(_inviteCodeKey);
      } catch (e) {
        AppLogger.log('Auth', '清除 sessionStorage 邀请码失败: $e');
      }
    } else {
      try {
        await SharedPreferences.getInstance().then((prefs) => prefs.remove(_inviteCodeKey));
      } catch (e) {
        AppLogger.log('Auth', '清除 SharedPreferences 邀请码失败: $e');
      }
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
  AuthController(this._ref) {
    // 从存储恢复待处理的邀请码（deep link 中获取的）
    unawaited(_restorePendingInviteCode());
  }
  final Ref _ref;
  AuthRepository get _repository => _ref.read(authRepositoryProvider);
  final Dio _apiDio = createBackendDio(baseUrl: api_config.apiBaseUrl);
  String? _pendingInviteCode;

  Future<void> _restorePendingInviteCode() async {
    try {
      _pendingInviteCode = await AuthSessionNotifier._readInviteCode();
    } catch (e) {
      AppLogger.log('Auth', '恢复待处理邀请码失败: $e');
    }
  }

  Future<void> requestEmailOtp(String email) => _repository.sendEmailOtp(email);

  /// 存储 deep link 中的邀请码（注册/登录前调用，登录成功后自动清除）。
  void setPendingInviteCode(String code) {
    if (code.isEmpty) return;
    _pendingInviteCode = code.trim().toUpperCase();
    // 持久化到存储，确保 app 重启后仍有效
    AuthSessionNotifier._writeInviteCode(_pendingInviteCode!);
    AppLogger.log('Auth', 'pending invite code set: $_pendingInviteCode');
  }

  Future<AuthResponse?> verifyEmailOtp({required String email, required String token}) async {
    try {
      final response = await _repository.verifyEmailOtp(
        email: email,
        token: token,
        inviteCode: _pendingInviteCode,
      );
      // 登录成功后清除待处理的邀请码
      if (response.userId != null) {
        _pendingInviteCode = null;
        await AuthSessionNotifier._clearInviteCode();
        AppLogger.log('Auth', 'invite code consumed: clear pending');
      }
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
        // Update storage and Riverpod state
        AuthSessionNotifier._writeSessionToStorage(updatedSession.toJson().toString());
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
