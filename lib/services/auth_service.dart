import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import 'backend_service.dart';

/// Google OAuth Authentication Service
/// Uses backend OAuth flow matching the reference iOS GoogleAuthService.
/// The backend provides the auth URL, handles the callback, and redirects
/// back to the app with tokens via custom URL scheme.
class AuthService extends ChangeNotifier {
  final BackendService _backend = BackendService();

  // Custom URL scheme for OAuth callback — reversed client ID from .env
  static const String _callbackScheme =
      'com.googleusercontent.apps.520426786442-bgrp1vlc49i7g082cb36sk2ovk9mt2gj';

  bool _isSignedIn = false;
  bool _isLoading = false;
  String? _error;
  UserAccount? _currentUser;
  final List<UserAccount> _accounts = [];

  bool get isSignedIn => _isSignedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserAccount? get currentUser => _currentUser;
  List<UserAccount> get accounts => List.unmodifiable(_accounts);

  AuthService() {
    _loadSavedAccounts();
  }

  // ──────────────────────────────────────────────
  // Session Persistence
  // ──────────────────────────────────────────────

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('voidmail_accounts');
    if (accountsJson != null) {
      try {
        final list = jsonDecode(accountsJson) as List;
        _accounts.clear();
        for (final item in list) {
          final account = UserAccount.fromJson(item);
          _accounts.add(account);
        }
        if (_accounts.isNotEmpty) {
          _currentUser = _accounts.first;
          _isSignedIn = true;
          if (_currentUser?.accessToken != null) {
            _backend.setToken(_currentUser!.accessToken!);
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading accounts: $e');
      }
    }
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _accounts.map((a) => a.toJson()).toList();
    await prefs.setString('voidmail_accounts', jsonEncode(json));
  }

  // ──────────────────────────────────────────────
  // Sign In with Google (Backend OAuth Flow)
  // ──────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Check if backend is reachable
      final backendOnline = await _backend.healthCheck();
      if (!backendOnline) {
        _error = 'Backend server is not reachable. Please check your connection.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Step 2: Get OAuth URL from backend (explicitly pass redirect_uri
      // so the backend uses one that matches Google Console config)
      final authURL = await _backend.getAuthURL(
        redirectUri: '${_backend.baseUrl}/auth/google/callback',
      );
      if (authURL == null) {
        _error = 'Could not generate auth URL from backend';
        _isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint('[Auth] Opening OAuth URL in browser...');

      // Step 3: Open browser for OAuth — backend callback redirects back
      // to our custom URL scheme with tokens as query params
      final resultUrl = await FlutterWebAuth2.authenticate(
        url: authURL,
        callbackUrlScheme: _callbackScheme,
      );

      debugPrint('[Auth] Got callback URL');

      // Step 4: Parse tokens and user data from callback URL
      final uri = Uri.parse(resultUrl);
      final params = uri.queryParameters;

      // Check for OAuth error
      if (params.containsKey('error')) {
        _error = 'Sign in failed: ${params['error']}';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final accessToken = params['access_token'];
      if (accessToken == null || accessToken.isEmpty) {
        _error = 'No access token received from backend';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Step 5: Build user account from callback parameters
      final account = UserAccount(
        id: params['user_id'] ?? '',
        email: params['user_email'] ?? '',
        displayName: params['user_name'] ?? params['user_email'] ?? '',
        photoURL: params['user_picture'],
        provider: AccountProvider.google,
        isPrimary: _accounts.isEmpty,
        accessToken: accessToken,
        refreshToken: params['refresh_token'],
        colorTag: _nextColor(),
      );

      // Step 6: Add or update account
      _accounts.removeWhere((a) => a.email == account.email);
      _accounts.add(account);
      _currentUser = account;
      _isSignedIn = true;

      _backend.setToken(accessToken);
      await _saveAccounts();

      debugPrint('[Auth] Signed in as ${account.email}');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // User cancelled the browser flow
      if (e.toString().contains('CANCELED') ||
          e.toString().contains('cancelled') ||
          e.toString().contains('canceled')) {
        debugPrint('[Auth] User cancelled sign-in');
        _error = null;
      } else {
        debugPrint('[Auth] Sign-in error: $e');
        _error = e.toString();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add another Google account
  Future<void> addAccount() async {
    await signInWithGoogle();
  }

  // ──────────────────────────────────────────────
  // Token Refresh
  // ──────────────────────────────────────────────

  /// Refresh access token for the current or specified account.
  Future<String?> refreshAccessToken({String? email}) async {
    final targetEmail = email ?? _currentUser?.email;
    if (targetEmail == null) return null;

    final accountIndex = _accounts.indexWhere((a) => a.email == targetEmail);
    if (accountIndex == -1) return null;

    final account = _accounts[accountIndex];

    // Use backend refresh endpoint with stored refresh token
    if (account.refreshToken != null) {
      final response = await _backend.refreshToken(account.refreshToken!);
      if (response != null && response['tokens'] != null) {
        final tokens = response['tokens'] as Map<String, dynamic>;
        final newAccessToken = tokens['access_token'] as String?;
        if (newAccessToken != null) {
          account.accessToken = newAccessToken;
          if (_currentUser?.email == targetEmail) {
            _backend.setToken(newAccessToken);
          }
          await _saveAccounts();
          notifyListeners();
          return newAccessToken;
        }
      }
    }

    // If refresh failed, user needs to re-authenticate
    debugPrint('[Auth] Token refresh failed for $targetEmail — re-auth needed');
    return null;
  }

  /// Get the access token for a specific account (or current).
  String? getAccessToken({String? email}) {
    if (email != null) {
      return _accounts
          .where((a) => a.email == email)
          .map((a) => a.accessToken)
          .firstOrNull;
    }
    return _currentUser?.accessToken;
  }

  /// Get all account tokens for multi-account fetching.
  List<({String email, String token})> getAllAccountTokens() {
    return _accounts
        .where((a) => a.accessToken != null)
        .map((a) => (email: a.email, token: a.accessToken!))
        .toList();
  }

  // ──────────────────────────────────────────────
  // Account Management
  // ──────────────────────────────────────────────

  AccountColor _nextColor() {
    final usedColors = _accounts.map((a) => a.colorTag).toSet();
    for (final color in AccountColor.values) {
      if (!usedColors.contains(color)) return color;
    }
    return AccountColor.pink;
  }

  Future<void> signOut() async {
    // Revoke all tokens via backend (fire and forget)
    for (final account in _accounts) {
      if (account.accessToken != null) {
        _backend.revokeToken(token: account.accessToken);
      }
    }

    _accounts.clear();
    _currentUser = null;
    _isSignedIn = false;
    _error = null;
    _backend.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('voidmail_accounts');

    notifyListeners();
  }

  Future<void> removeAccount(String email) async {
    // Revoke token for this account
    final account = _accounts.where((a) => a.email == email).firstOrNull;
    if (account?.accessToken != null) {
      _backend.revokeToken(token: account!.accessToken);
    }

    _accounts.removeWhere((a) => a.email == email);

    if (_accounts.isEmpty) {
      await signOut();
    } else {
      if (_currentUser?.email == email) {
        _currentUser = _accounts.first;
        if (_currentUser?.accessToken != null) {
          _backend.setToken(_currentUser!.accessToken!);
        }
      }
      await _saveAccounts();
      notifyListeners();
    }
  }

  void setAccountColor(String email, AccountColor color) {
    final account = _accounts.firstWhere((a) => a.email == email);
    account.colorTag = color;
    _saveAccounts();
    notifyListeners();
  }

  void setAccountLabel(String email, String label) {
    final account = _accounts.firstWhere((a) => a.email == email);
    account.label = label;
    _saveAccounts();
    notifyListeners();
  }

  void switchAccount(String email) {
    final account = _accounts.firstWhere((a) => a.email == email);
    _currentUser = account;
    if (account.accessToken != null) {
      _backend.setToken(account.accessToken!);
    }
    notifyListeners();
  }
}
