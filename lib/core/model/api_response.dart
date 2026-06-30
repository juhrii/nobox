// =====================================================================
// FITUR: Model API Response
// FILE: lib/core/model/api_response.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Class dasar untuk menampung format balasan/response dari HTTP Request
// =====================================================================
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

  // FITUR: Factory Success Response
  // FUNGSI: Membuat objek ApiResponse jika request berhasil (status 200/201 dll)
  factory ApiResponse.success(T data, int statusCode) {
    return ApiResponse(
      isError: false,
      data: data,
      statusCode: statusCode,
    );
  }

  // FITUR: Factory Failure Response
  // FUNGSI: Membuat objek ApiResponse jika request gagal (status 400/500 dll)
  factory ApiResponse.failure(String error, int statusCode) {
    return ApiResponse(
      isError: true,
      error: error,
      statusCode: statusCode,
    );
  }
}
