class InvidiousServiceError extends Error {
  final String message;
  final int? statusCode;
  final bool responseWasHtml;
  final Duration? retryAfter;

  InvidiousServiceError(
    this.message, {
    this.statusCode,
    this.responseWasHtml = false,
    this.retryAfter,
  });

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}
