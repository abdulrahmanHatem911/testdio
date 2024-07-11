import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:test_dio_package/core/helper/loger.dart';

class AppString {
  static const String noInternetConnection = 'No internet connection';
  static const String connectionTimeout = 'Connection timeout';
  static const String sendTimeout = 'Send timeout';
  static const String receiveTimeout = 'Receive timeout';
  static const String resourceNotFound = 'Resource not found: 404';
  static const String internalServerError = 'Internal server error: 500';
  static const String requestCancelled = 'Request cancelled';
  static const String unexpectedError = 'Unexpected error';
  static const String unknownError = 'Unknown error';

  static const String badRequest = 'Bad request';
  static const String unauthorized = 'Unauthorized';
  static const String forbidden = 'Forbidden';
  static const String notFound = 'Not found';
  static const String duplicateEmail = 'Duplicate email';
  static const String badGateway = 'Bad gateway';
  static const String unsupportedMediaType = 'Unsupported Media Type: 415';
  static const String resourceCreated = 'Resource successfully created: 201';
  static const String accountSuspended = 'هذا الحساب موقوف';
}

class AutomaticallyService {
  String? _baseUrl;
  final Dio _dio = Dio();
  static final instance = AutomaticallyService._();
  final LoggerDebug log =
      LoggerDebug(headColor: LogColors.red, constTitle: "Server Gate Logger");

  AutomaticallyService._() {
    addInterceptors();
  }

  CancelToken cancelToken = CancelToken();

  Map<String, dynamic> _header({String contentType = Headers.jsonContentType}) {
    return {
      "Accept": "application/json",
      "Content-Type": Headers.jsonContentType,
      // update
      "lang": "ar",
    };
  }

  void addInterceptors() {
    _dio.interceptors.add(CustomApiInterceptor(log));
  }

  StreamController<double> onSingleReceive = StreamController.broadcast();

  Future<CustomResponse<T>> sendToServer<T>({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? params,
    T Function(dynamic)? callback,
    bool withoutHeader = false,
    String attribute = "data",
  }) async {
    await _getBaseUrl();

    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      return CustomResponse<T>(
        success: false,
        errType: 0,
        msg: AppString.noInternetConnection,
      );
    }

    body?.removeWhere((key, value) => value == null || value == "");
    params?.removeWhere((key, value) => value == null || value == "");

    if (headers == null) {
      headers = _header();
    } else {
      if (!withoutHeader) headers.addAll(_header());
      headers.removeWhere((key, value) => value == null || value == "");
    }

    log.white("Request body: ${jsonEncode(body)}");
    log.white("Request params: ${jsonEncode(params)}");

    dynamic prepareRequestBody(Map<String, dynamic>? body) {
      if (body != null && body.values.any((value) => value is MultipartFile)) {
        return FormData.fromMap(body);
      } else {
        return jsonEncode(body ?? {});
      }
    }

    try {
      final options = Options(
        headers: withoutHeader ? null : (headers),
        contentType:
            body != null && body.values.any((value) => value is MultipartFile)
                ? Headers.formUrlEncodedContentType
                : Headers.jsonContentType,
        responseType: ResponseType.json,
      );

      dynamic requestBody = withoutHeader ? body : prepareRequestBody(body);

      final response = await _executeRequest(
        url: url,
        requestBody: requestBody,
        params: params,
        options: options,
        method: method,
      );

      log.green(
          "Response: ${jsonEncode(response.data)} (Status code: ${response.statusCode})");

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        if (response.statusCode == 201) {
          log.green(
              "Resource created at: ${response.headers['Location']?.first ?? ''}");
        }
        return CustomResponse<T>(
          success: true,
          statusCode: response.statusCode!,
          data: callback != null ? callback(response.data) : response.data,
        );
      } else {
        return CustomResponse<T>(
          success: false,
          statusCode: response.statusCode!,
          msg: _handleError(response.statusCode, response.data),
        );
      }
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    }
  }

  Future<Response> _executeRequest({
    required String url,
    required dynamic requestBody,
    required Map<String, dynamic>? params,
    required Options options,
    required String method,
  }) async {
    final requestUrl = url.startsWith("http") ? url : "$_baseUrl/$url";
    switch (method) {
      case 'POST':
        return await _dio.post(requestUrl,
            data: requestBody, queryParameters: params, options: options);
      case 'GET':
        return await _dio.get(requestUrl,
            queryParameters: params, options: options);
      case 'PUT':
        return await _dio.put(requestUrl,
            data: requestBody, queryParameters: params, options: options);
      case 'DELETE':
        return await _dio.delete(requestUrl,
            queryParameters: params, options: options);
      default:
        throw UnsupportedError('Unsupported method: $method');
    }
  }

  final Map<String, String> _cachedImage = {};
  final Dio _imageDio = Dio();

  Future<String?> imageBase64(String url) async {
    final imageName = url.split("/").last;

    if (_cachedImage.length >= 70) _cachedImage.clear();
    if (_cachedImage.containsKey(imageName)) {
      return _cachedImage[imageName];
    }

    final result = await _imageDio.get(url,
        options: Options(responseType: ResponseType.bytes));
    if (result.statusCode == 200) {
      final imageEncoder = base64Encode(result.data);
      _cachedImage[imageName] = imageEncoder;
      return imageEncoder;
    } else {
      return null;
    }
  }

  Future<String?> _getBaseUrl() async {
    _baseUrl = "https://makeup-api.herokuapp.com/api";
    String? url;
    try {
      if (_baseUrl != null) return _baseUrl;
      final result = await _dio.get(
        url!,
        options: Options(
          headers: {"Accept": "application/json"},
          sendTimeout: const Duration(milliseconds: 5000),
          receiveTimeout: const Duration(milliseconds: 5000),
        ),
      );
      if (result.data != null) {
        _baseUrl = result.data;
        log.red("------Base url -----\x1B[31m$_baseUrl\x1B[0m");
        return _baseUrl;
      } else {
        throw DioException(
          requestOptions: result.requestOptions,
          response: Response(
            requestOptions: result.requestOptions,
            data: {"message": "لم نستتطع الاتصال بالسيرفر"},
          ),
          type: DioExceptionType.badResponse,
        );
      }
    } catch (e) {
      final requestOptions = RequestOptions(path: url!);
      throw DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          data: {"message": "حدث خطآ عند الاتصال بالسيرفر"},
        ),
        type: DioExceptionType.badResponse,
      );
    }
  }

  String _handleError(int? statusCode, dynamic error) {
    if (error is Map && error['message'] == AppString.accountSuspended) {
      return AppString.accountSuspended; // Specific error message in Arabic
    }
    switch (statusCode) {
      case 400:
        return AppString.badRequest;
      case 401:
        return AppString.unauthorized;
      case 403:
        return AppString.forbidden;
      case 404:
        return AppString.notFound;
      case 415:
        return AppString.unsupportedMediaType;
      case 422:
        return AppString.duplicateEmail;
      case 500:
        return AppString.internalServerError;
      case 502:
        return AppString.badGateway;
      default:
        return AppString.unknownError;
    }
  }

  CustomResponse<T> _handleDioError<T>(DioException e) {
    String errorMessage;
    int errorType;

    if (e.response?.data is Map &&
        e.response?.data['message'] == AppString.accountSuspended) {
      errorMessage =
          AppString.accountSuspended; // Specific error message in Arabic
      errorType = 1;
    } else {
      if (e.response?.headers.value('content-type')?.contains('text/html') ??
          false) {
        final errorHtml = e.response?.data.toString() ?? 'Unknown HTML error';
        errorMessage = "Error Response (HTML): $errorHtml";
        errorType = 1;
      } else {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = AppString.connectionTimeout;
            errorType = 0;
            break;
          case DioExceptionType.badResponse:
            errorMessage =
                _handleError(e.response?.statusCode, e.response?.data);
            errorType = 1;
            break;
          case DioExceptionType.cancel:
            errorMessage = AppString.requestCancelled;
            errorType = 2;
            break;
          case DioExceptionType.connectionError:
            errorMessage = AppString.noInternetConnection;
            errorType = 0;
            break;
          default:
            errorMessage = AppString.unknownError;
            errorType = 2;
        }
      }
    }

    return CustomResponse<T>(
      success: false,
      errType: errorType,
      msg: errorMessage,
      statusCode: e.response?.statusCode ?? 0,
      response: e.response,
    );
  }

  Future<CustomResponse<T>> downloadFile<T>({
    required String url,
    required String savePath,
    Map<String, dynamic>? headers,
  }) async {
    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      return CustomResponse<T>(
        success: false,
        errType: 0,
        msg: AppString.noInternetConnection,
      );
    }

    try {
      final response = await _dio.download(
        url,
        savePath,
        options: Options(headers: headers ?? _header()),
      );

      log.green("Response: (Status code: ${response.statusCode})");

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        return CustomResponse<T>(
          success: true,
          statusCode: response.statusCode!,
        );
      } else {
        return CustomResponse<T>(
          success: false,
          statusCode: response.statusCode!,
          msg: _handleError(response.statusCode, response.data),
        );
      }
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    }
  }
}

class CustomApiInterceptor extends Interceptor {
  LoggerDebug log;

  CustomApiInterceptor(this.log);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Check if the error response is HTML content
    if (err.response?.headers.value('content-type')?.contains('text/html') ??
        false) {
      final errorHtml = err.response?.data.toString() ?? 'Unknown HTML error';
      log.red(
          "Error Response (HTML): $errorHtml (Status code: ${err.response?.statusCode})");
    } else {
      log.red(
          "Error Response: ${err.response?.data} (Status code: ${err.response?.statusCode})");
    }

    if (err.response?.statusCode == 302) {
      final newUrl = err.response?.headers.value('location');
      if (newUrl != null) {
        final options = err.requestOptions;
        options.path = newUrl;

        try {
          final response = await Dio().fetch(options);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
    }

    return super.onError(err, handler);
  }

  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    log.green("------ Current Response ------");
    log.green(jsonEncode(response.data));
    return super.onResponse(response, handler);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log.cyan("------ Current Request Parameters Data -----");
    log.cyan("${options.queryParameters}");
    log.yellow("------ Current Request Headers -----");
    log.yellow("${options.headers}");
    log.green("------ Current Request Path -----");
    log.green(
        "${options.path} ${LogColors.red}API METHOD : (${options.method})${LogColors.reset}");
    return super.onRequest(options, handler);
  }
}

class CustomResponse<T> {
  bool success;
  int? errType;
  String msg;
  int statusCode;
  Response? response;
  T? data;

  CustomResponse({
    this.success = false,
    this.errType = 0,
    this.msg = "",
    this.statusCode = 0,
    this.response,
    this.data,
  });
}

class CustomError {
  int? type;
  String? msg;
  dynamic error;

  CustomError({
    this.type,
    this.msg,
    this.error,
  });
}
