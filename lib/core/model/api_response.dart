class ApiResponse<T> {
  final bool isError;
  final String? error;
  final T? data;
  final int statusCode;

  ApiResponse({
    required this.isError,
    this.error,
    this.data,
    required this.statusCode,
  });

  factory ApiResponse.success(T data, int statusCode) {
    return ApiResponse(
      isError: false,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.failure(String error, int statusCode) {
    return ApiResponse(
      isError: true,
      error: error,
      statusCode: statusCode,
    );
  }
}
