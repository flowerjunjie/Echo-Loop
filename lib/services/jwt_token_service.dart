import 'package:jwt/jwt.dart';

import '../config/jwt_config.dart';

/// JWT token service for generating authentication tokens
/// that the transcription API expects.
class JwtTokenService {
  final String _secret;

  JwtTokenService(this._secret);

  /// Get the default secret from compile-time environment variable
  static String get defaultSecret => jwtConfig.jwtSecret;

  Future<String> generateToken({required String userId, required String email?, required String secret}) async {
    final payload = {
      'userId': userId,
      if (email != null) 'email': email,
      'exp': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
    };
    final encoded = jwt.encode(
      Payload(payload),
      secret,
      algorithm: Algorithm.hs256(),
    );
    return encoded;
  }

  /// Generate token using the default secret from compile-time config
  Future<String> generateDefaultToken({required String userId, required String email?}) async {
    final secret = JwtConfig.defaultSecret;
    return generateToken(userId: userId, email: email, secret: secret);
  }

  // Decode for verification/testing
  Map<String, dynamic> decode(String token) {
    final decoded = JwtParser().decode(token);
    return decoded!.payload;
  }
}