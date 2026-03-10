import 'dart:convert';
import 'package:http/http.dart' as http;

/// Callback type for token refresh — set by AuthService
typedef TokenRefreshCallback = Future<String?> Function();

/// Centralized HTTP API client for VoidMail backend
/// Mirrors the Swift BackendService from the reference iOS app.
class BackendService {
  // Backend URL - Vercel deployment
  static const String _baseUrl = 'https://void-mail.vercel.app';

  String? _accessToken;

  /// Callback to refresh the access token on 401 responses
  TokenRefreshCallback? onTokenRefresh;

  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  void setToken(String token) {
    _accessToken = token;
  }

  void clearToken() {
    _accessToken = null;
  }

  String get baseUrl => _baseUrl;
  String? get accessToken => _accessToken;

  Map<String, String> _buildHeaders({String? token}) {
    final t = token ?? _accessToken;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // ──────────────────────────────────────────────
  // Auth Endpoints
  // ──────────────────────────────────────────────

  /// Gets the Google OAuth URL from the backend.
  Future<String?> getAuthURL({String? redirectUri}) async {
    try {
      String path = '/auth/google';
      if (redirectUri != null) {
        path += '?redirect_uri=${Uri.encodeComponent(redirectUri)}';
      }
      final response = await get(path);
      return response['authUrl'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Exchanges an authorization code for tokens via the backend.
  Future<Map<String, dynamic>?> exchangeCode(String code,
      {String? redirectUri}) async {
    try {
      final body = <String, dynamic>{'code': code};
      if (redirectUri != null) body['redirect_uri'] = redirectUri;
      return await post('/auth/google/token', body: body);
    } catch (e) {
      return null;
    }
  }

  /// Refreshes an expired access token via the backend.
  Future<Map<String, dynamic>?> refreshToken(String refreshToken) async {
    try {
      return await post('/auth/google/refresh', body: {
        'refresh_token': refreshToken,
      });
    } catch (e) {
      return null;
    }
  }

  /// Gets the current user's profile.
  Future<Map<String, dynamic>?> getMe({String? token}) async {
    try {
      final response = await get('/auth/me', token: token);
      return response['user'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Revoke access token (sign out).
  Future<bool> revokeToken({String? token}) async {
    try {
      await post('/auth/revoke', body: {}, token: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // Health Check
  // ──────────────────────────────────────────────

  /// Check if the backend is reachable and properly configured.
  Future<bool> healthCheck() async {
    try {
      final response = await get('/health');
      return response['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  /// Check if the Helix AI service is operational.
  Future<Map<String, dynamic>?> helixStatus() async {
    try {
      return await get('/api/helix/status');
    } catch (e) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // HTTP Methods (with 401 auto-retry)
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? queryParams, String? token}) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http
        .get(uri, headers: _buildHeaders(token: token))
        .timeout(const Duration(seconds: 15));

    // Auto-retry on 401 with token refresh
    if (response.statusCode == 401 && token == null && onTokenRefresh != null) {
      final newToken = await onTokenRefresh!();
      if (newToken != null) {
        final retryResponse = await http
            .get(uri, headers: _buildHeaders())
            .timeout(const Duration(seconds: 15));
        return _handleResponse(retryResponse);
      }
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body, String? token}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http
        .post(uri, headers: _buildHeaders(token: token), body: encodedBody)
        .timeout(const Duration(seconds: 30));

    // Auto-retry on 401 with token refresh
    if (response.statusCode == 401 && token == null && onTokenRefresh != null) {
      final newToken = await onTokenRefresh!();
      if (newToken != null) {
        final retryResponse = await http
            .post(uri, headers: _buildHeaders(), body: encodedBody)
            .timeout(const Duration(seconds: 30));
        return _handleResponse(retryResponse);
      }
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body, String? token}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http
        .put(uri, headers: _buildHeaders(token: token), body: encodedBody)
        .timeout(const Duration(seconds: 30));

    // Auto-retry on 401 with token refresh
    if (response.statusCode == 401 && token == null && onTokenRefresh != null) {
      final newToken = await onTokenRefresh!();
      if (newToken != null) {
        final retryResponse = await http
            .put(uri, headers: _buildHeaders(), body: encodedBody)
            .timeout(const Duration(seconds: 30));
        return _handleResponse(retryResponse);
      }
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http
        .delete(uri, headers: _buildHeaders(token: token))
        .timeout(const Duration(seconds: 15));

    // Auto-retry on 401 with token refresh
    if (response.statusCode == 401 && token == null && onTokenRefresh != null) {
      final newToken = await onTokenRefresh!();
      if (newToken != null) {
        final retryResponse = await http
            .delete(uri, headers: _buildHeaders())
            .timeout(const Duration(seconds: 15));
        return _handleResponse(retryResponse);
      }
    }

    return _handleResponse(response);
  }

  /// Download raw bytes (for attachment downloads)
  Future<List<int>?> getBytes(String path, {String? token}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http
        .get(uri, headers: _buildHeaders(token: token))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401 && token == null && onTokenRefresh != null) {
      final newToken = await onTokenRefresh!();
      if (newToken != null) {
        final retryResponse = await http
            .get(uri, headers: _buildHeaders())
            .timeout(const Duration(seconds: 30));
        if (retryResponse.statusCode >= 200 && retryResponse.statusCode < 300) {
          return retryResponse.bodyBytes;
        }
        return null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    return null;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {'success': true};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      } catch (_) {
        return {'data': response.body};
      }
    }
    throw BackendException(
      statusCode: response.statusCode,
      message: response.body,
    );
  }
}

class BackendException implements Exception {
  final int statusCode;
  final String message;

  BackendException({required this.statusCode, required this.message});

  @override
  String toString() => 'BackendException($statusCode): $message';
}
