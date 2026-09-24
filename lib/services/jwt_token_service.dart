/// JWT token service (placeholder for Web build)
library;

/// JWT token service for generating authentication tokens
class JwtTokenService {
  static const String defaultSecret = 'web-placeholder-secret';

  Future<String> generateToken({
    required String userId,
    String? email,
    required String secret,
  }) async {
    // Simplified JWT generation for Web
    return 'web-token-placeholder';
  }

  Future<String> generateDefaultToken({
    required String userId,
    String? email,
  }) async {
    return generateToken(
      userId: userId,
      email: email,
      secret: defaultSecret,
    );
  }
}
