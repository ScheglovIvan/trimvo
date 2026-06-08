import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:trimvo/core/constants/api_constants.dart';
import 'package:trimvo/models/gem_package_model.dart';

class ApiService {
  ApiService._();

  static const String baseUrl = ApiConstants.apiBase;
  static String? fixUrl(String? url) => ApiConstants.fixUrl(url);
  static String? token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Auth ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );
    return _parse(response);
  }

  /// Returns gems + full subscription info for the current user.
  /// Endpoint: GET /v1/me/gems  (requires Bearer token)
  static Future<Map<String, dynamic>> getGemsBalance() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/gems'),
      headers: _headers,
    );
    return _parse(response);
  }

  // ── Templates ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTemplates({
    String? categoryId,
    bool? trending,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (categoryId != null && categoryId.isNotEmpty) {
      params['category'] = categoryId;
    }
    if (trending == true) params['trending'] = 'true';

    final uri = Uri.parse('$baseUrl/templates').replace(queryParameters: params);
    debugPrint('getTemplates: $uri');
    final response = await http.get(uri, headers: _headers);
    debugPrint('getTemplates response: ${response.statusCode} ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    return _parse(response);
  }

  static Future<Map<String, dynamic>> getCategoryTemplates(
      String categoryId) async {
    final uri = Uri.parse('$baseUrl/categories/$categoryId/templates');
    debugPrint('getCategoryTemplates: $uri');
    final response = await http.get(uri, headers: _headers);
    debugPrint('getCategoryTemplates response: ${response.statusCode}');
    if (response.statusCode >= 400) {
      throw ApiException(_safeErrorMessage(response), response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return {'items': decoded, 'total': decoded.length};
    }
    return decoded as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTemplate(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/templates/$id'),
      headers: _headers,
    );
    return _parse(response);
  }

  // ── Reports ─────────────────────────────────────────────────────────────────

  static Future<void> submitReport(String templateId, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reports'),
      headers: _headers,
      body: jsonEncode({'template_id': templateId, 'reason': reason}),
    );
    if (response.statusCode >= 400) {
      throw ApiException(_safeErrorMessage(response), response.statusCode);
    }
  }

  // ── Categories ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiException(_safeErrorMessage(response), response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map) {
      final items = decoded['items'] as List<dynamic>?;
      return items?.cast<Map<String, dynamic>>() ?? [];
    }
    return [];
  }

  // ── Gem Packages ─────────────────────────────────────────────────────────────

  static Future<List<GemPackageModel>> getGemPackages() async {
    final response = await http.get(
      Uri.parse('$baseUrl/gem-packages'),
      headers: _headers,
    );
    debugPrint('[GemPackages] status=${response.statusCode} body=${response.body.substring(0, response.body.length.clamp(0, 500))}');
    if (response.statusCode >= 400) {
      throw ApiException(_safeErrorMessage(response), response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      items = (decoded['items'] as List<dynamic>?) ?? [];
    } else {
      items = [];
    }
    final packages = items
        .map((e) => GemPackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final p in packages) {
      debugPrint('[GemPackages] id=${p.id} gems=${p.gemsAmount} appleProductId=${p.appleProductId}');
    }
    return packages;
  }

  // ── Subscription Plans ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    final response = await http.get(
      Uri.parse('$baseUrl/subscription-plans'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiException(_safeErrorMessage(response), response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map) {
      final items = decoded['items'] as List<dynamic>?;
      return items?.cast<Map<String, dynamic>>() ?? [];
    }
    return [];
  }

  // ── Pricing ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPricing() async {
    final response = await http.get(
      Uri.parse('$baseUrl/pricing'),
      headers: _headers,
    );
    return _parse(response);
  }

  // ── Jobs ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createJob(
    String? templateId,
    Map<String, dynamic> options,
  ) async {
    if (templateId == null || templateId.isEmpty) {
      throw const ApiException('template_id is required', 400);
    }
    final body = <String, dynamic>{'options': options, 'template_id': templateId};
    debugPrint('[createJob] POST $baseUrl/jobs body=${jsonEncode(body)}');
    final response = await http.post(
      Uri.parse('$baseUrl/jobs'),
      headers: _headers,
      body: jsonEncode(body),
    );
    debugPrint('[createJob] ${response.statusCode} ${response.body}');
    return _parse(response);
  }

  static Future<Map<String, dynamic>> createCustomJob({
    required String photo1Path,
    String? photo2Path,
    String prompt = '',
    String resolution = '1080x1920',
    String quality = 'standard',
    String format = 'mp4',
  }) async {
    final uri = Uri.parse('$baseUrl/jobs/custom');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['prompt'] = prompt;
    request.fields['resolution'] = resolution;
    request.fields['quality'] = quality;
    request.fields['format'] = format;

    final f1 = await _fileForPathOrUrl(photo1Path);
    request.files.add(await http.MultipartFile.fromPath(
      'photo_1',
      f1.path,
      contentType: _mimeFromPath(f1.path),
    ));

    if (photo2Path != null) {
      final f2 = await _fileForPathOrUrl(photo2Path);
      request.files.add(await http.MultipartFile.fromPath(
        'photo_2',
        f2.path,
        contentType: _mimeFromPath(f2.path),
      ));
    }

    final streamed = await request.send()
        .timeout(ApiConstants.requestTimeout);
    final response = await http.Response.fromStream(streamed);
    return _parse(response);
  }

  static Future<Map<String, dynamic>> createImageJob({
    required String photoPath,
    String prompt = '',
    String aspectRatio = '1:1',
    int numOutputs = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/jobs/image');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['prompt'] = prompt;
    request.fields['aspect_ratio'] = aspectRatio;
    request.fields['count'] = '$numOutputs';

    final file = await _fileForPathOrUrl(photoPath);
    request.files.add(await http.MultipartFile.fromPath(
      'photo',
      file.path,
      contentType: _mimeFromPath(file.path),
    ));

    final streamed = await request.send().timeout(ApiConstants.requestTimeout);
    final response = await http.Response.fromStream(streamed);
    return _parse(response);
  }

  /// Uploads a local photo file to the server and returns its public URL.
  /// Call before createJob to avoid passing Android local paths to the backend.
  static Future<String> uploadPhoto(String localPath) async {
    final uri = Uri.parse('$baseUrl/uploads/photo');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        localPath,
        contentType: _mimeFromPath(localPath),
      ),
    );
    final streamed =
        await request.send().timeout(ApiConstants.requestTimeout);
    final response = await http.Response.fromStream(streamed);
    final body = _parse(response);
    final url = body['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('Upload failed: no URL returned');
    }
    return url;
  }

  static MediaType _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('image', 'jpeg');
  }

  static Future<File> _fileForPathOrUrl(String pathOrUrl) async {
    if (!pathOrUrl.startsWith('http')) return File(pathOrUrl);
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(pathOrUrl)));
      final tmp = File(
        '${Directory.systemTemp.path}/hc_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final sink = tmp.openWrite();
      await response.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      return tmp;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/jobs/$jobId'),
      headers: _headers,
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> getUserJobs({
    int page = 1,
    int perPage = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/jobs').replace(
      queryParameters: {'page': '$page', 'per_page': '$perPage'},
    );
    final response = await http.get(uri, headers: _headers);
    return _parse(response);
  }

  static Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/me/account'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiException(
        _safeErrorMessage(response, 'Failed to delete account'),
        response.statusCode,
      );
    }
  }

  static Future<void> deleteJob(String jobId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/jobs/$jobId'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw ApiException(_safeErrorMessage(response, 'Delete failed'), response.statusCode);
    }
  }

  // ── Apple IAP ───────────────────────────────────────────────────────────────

  /// POST /v1/payments/apple/verify-purchase
  static Future<Map<String, dynamic>> verifyApplePurchase({
    required String jwsRepresentation,
    required String packageId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/apple/verify-purchase'),
      headers: _headers,
      body: jsonEncode({
        'jws_representation': jwsRepresentation,
        'package_id': packageId,
      }),
    );
    return _parse(response);
  }

  /// POST /v1/payments/apple/verify-subscription
  static Future<Map<String, dynamic>> verifyAppleSubscription({
    required String jwsRepresentation,
    required String planId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/apple/verify-subscription'),
      headers: _headers,
      body: jsonEncode({
        'jws_representation': jwsRepresentation,
        'plan_id': planId,
      }),
    );
    return _parse(response);
  }

  /// POST /v1/payments/apple/restore
  static Future<Map<String, dynamic>> restoreApplePurchases({
    required List<String> jwsRepresentations,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/apple/restore'),
      headers: _headers,
      body: jsonEncode({
        'transactions': jwsRepresentations
            .map((jws) => {'jws_representation': jws})
            .toList(),
      }),
    );
    return _parse(response);
  }

  // ── Onboarding ──────────────────────────────────────────────────────────────

  static Future<List<String>> getOnboardingVideos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/config/onboarding-video'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = ApiService.fixUrl(data['url']?.toString());
        if (url != null && url.isNotEmpty) return [url];
      }
    } catch (_) {}
    return [];
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _safeErrorMessage(http.Response response, [String fallback = 'Request failed']) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['detail']?.toString() ?? body['message']?.toString() ?? fallback;
    } catch (_) {
      final text = response.body.trim();
      return text.isNotEmpty && text.length < 300 ? text : fallback;
    }
  }

  static Map<String, dynamic> _parse(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(_safeErrorMessage(response), response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
