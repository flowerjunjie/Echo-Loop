/// Transcription API authentication JWT secret.
/// MUST be injected via --dart-define=TRANSCRIPTION_JWT_SECRET during production build.
/// Using the dev default in a release build is a security critical error.
class JwtConfig {
  /// Returns the configured JWT secret.
  /// In release mode without the dart-define injected, throws a fatal error —
  /// we'd rather crash at startup than sign JWTs with a known public key.
  static String get defaultSecret {
    final secret = String.fromEnvironment('TRANSCRIPTION_JWT_SECRET');
    if (secret.isEmpty) {
      throw StateError(
        'TRANSCRIPTION_JWT_SECRET must be provided via --dart-define in production builds. '
        'See .env.build or build config for instructions.',
      );
    }
    return secret;
  }
}