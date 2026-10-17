abstract final class AppBuildInfo {
  static const version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const commit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'development',
  );

  static String get shortCommit =>
      commit.length > 12 ? commit.substring(0, 12) : commit;
}
