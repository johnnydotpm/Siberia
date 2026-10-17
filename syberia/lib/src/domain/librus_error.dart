/// Provider-agnostic error vocabulary. The data layer throws these codes so
/// that no user-facing wording lives behind the repository boundary; the UI
/// turns a code into text through `AppLocalizations`.
enum LibrusErrorCode {
  missingCredentials,
  incompleteMessageForm,
  invalidCredentials,
  loginFailed,
  captchaRequired,
  noStoredAccount,
  sessionExpired,
  sessionRenewFailed,
  noSynergiaAccount,
  noSynergiaToken,
  portalRejected,
  apiRejected,
  messageNotSent,
  attachmentFetchFailed,
  messageContentFailed,
  networkTimeout,
  networkUnavailable,
  networkOther,
  networkUnknown,
  serverReply,
}

class LibrusException implements Exception {
  const LibrusException(this.errorCode, {this.detail, this.code});

  /// Localizable reason the request failed.
  final LibrusErrorCode errorCode;

  /// Value interpolated into the translation's `{detail}` placeholder: an
  /// HTTP status, or wording Librus itself supplied that cannot be
  /// translated.
  final String? detail;

  /// The `Code` field Librus returns on API errors. Untouched by
  /// localization and kept for diagnostics.
  final String? code;

  @override
  String toString() =>
      detail == null ? errorCode.name : '${errorCode.name}: $detail';
}

/// What the UI renders. Carries either a known [LibrusErrorCode] or, for
/// anything the data layer did not anticipate, the original text in [raw].
class AppError {
  const AppError({this.errorCode, this.detail, this.raw});

  factory AppError.from(Object error) => error is LibrusException
      ? AppError(
          errorCode: error.errorCode,
          detail: error.detail,
          raw: error.toString(),
        )
      : AppError(raw: error.toString());

  final LibrusErrorCode? errorCode;
  final String? detail;
  final String? raw;
}
