/// Transcription API authentication JWT secret.
/// Injected via --dart-define=TRANSCRIPTION_JWT_SECRET during build.
const String jwtSecret = String.fromEnvironment(
  'TRANSCRIPTION_JWT_SECRET',
  defaultValue: 'echo-loop-dev-secret-change-me',
);

/// Config class for providing default secret to services
class JwtConfig {
  static final defaultSecret = jwtSecret;
}