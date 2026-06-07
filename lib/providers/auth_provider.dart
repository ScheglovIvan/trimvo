import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trimvo/core/constants/api_constants.dart';
import 'package:trimvo/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sentinel for nullable copyWith params — lets callers explicitly pass null.
const Object _kUnset = Object();

class AuthState {
  const AuthState({
    this.isLoggedIn = false,
    this.token,
    this.userId,
    this.email,
    this.gems = 0,
    this.subscriptionStatus = 'free',
    this.subscriptionExpiresAt,
  });

  final bool isLoggedIn;
  final String? token;
  final String? userId;
  final String? email;
  final int gems;
  final String subscriptionStatus;
  final DateTime? subscriptionExpiresAt;

  bool get isSvip => subscriptionStatus == 'svip';
  bool get hasActiveSubscription =>
      subscriptionStatus.isNotEmpty && subscriptionStatus != 'free';

  AuthState copyWith({
    bool? isLoggedIn,
    String? token,
    String? userId,
    String? email,
    int? gems,
    String? subscriptionStatus,
    Object? subscriptionExpiresAt = _kUnset,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      gems: gems ?? this.gems,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiresAt: identical(subscriptionExpiresAt, _kUnset)
          ? this.subscriptionExpiresAt
          : subscriptionExpiresAt as DateTime?,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';
  static const _userIdKey = 'auth_user_id';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    if (savedToken != null && savedToken.isNotEmpty) {
      ApiService.token = savedToken;
      state = AuthState(
        isLoggedIn: true,
        token: savedToken,
        email: prefs.getString(_emailKey),
        userId: prefs.getString(_userIdKey),
      );
      try {
        final me = await ApiService.getMe();
        debugPrint('getMe response: $me');
        final userId = me['id']?.toString();
        final gems = (me['gems'] as num?)?.toInt() ?? 0;
        debugPrint('gems from API: $gems');
        final sub = me['subscription_status']?.toString() ?? 'free';
        final expiresAt = _parseExpiry(me);
        if (userId != null) await prefs.setString(_userIdKey, userId);
        state = state.copyWith(
          userId: userId, gems: gems, subscriptionStatus: sub,
          subscriptionExpiresAt: expiresAt,
        );
      } catch (e) {
        debugPrint('loadFromStorage getMe error: $e');
        if (e is ApiException && e.statusCode == 401) {
          final refreshed = await _tryRefreshToken(prefs);
          if (refreshed) {
            try {
              final me = await ApiService.getMe();
              final userId = me['id']?.toString();
              final gems = (me['gems'] as num?)?.toInt() ?? 0;
              final sub = me['subscription_status']?.toString() ?? 'free';
              final expiresAt = _parseExpiry(me);
              if (userId != null) await prefs.setString(_userIdKey, userId);
              state = state.copyWith(
                userId: userId, gems: gems, subscriptionStatus: sub,
                subscriptionExpiresAt: expiresAt,
              );
            } catch (_) {
              await _clearStorage(prefs);
            }
          } else {
            await _clearStorage(prefs);
          }
        }
      }
    }
  }

  Future<bool> _tryRefreshToken(SharedPreferences prefs) async {
    final refreshToken = prefs.getString(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.apiBase}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['access_token']?.toString() ?? '';
        if (newToken.isNotEmpty) {
          ApiService.token = newToken;
          await prefs.setString(_tokenKey, newToken);
          state = state.copyWith(token: newToken);
          debugPrint('Token refreshed successfully');
          return true;
        }
      }
    } catch (e) {
      debugPrint('Refresh token failed: $e');
    }
    return false;
  }

  Future<void> _clearStorage(SharedPreferences prefs) async {
    ApiService.token = null;
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_refreshTokenKey);
    state = const AuthState();
    debugPrint('Storage cleared — user logged out');
  }

  Future<void> login(String email, String password) async {
    final data = await ApiService.login(email, password);
    final token = data['access_token']?.toString() ?? '';
    final refreshToken = data['refresh_token']?.toString() ?? '';
    ApiService.token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_emailKey, email);
    if (refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }

    state = AuthState(isLoggedIn: true, token: token, email: email);

    try {
      final me = await ApiService.getMe();
      final userId = me['id']?.toString();
      final gems = (me['gems'] as num?)?.toInt() ?? 0;
      final sub = me['subscription_status']?.toString();
      final expiresAt = _parseExpiry(me);
      if (userId != null) await prefs.setString(_userIdKey, userId);
      state = state.copyWith(
        userId: userId, gems: gems, subscriptionStatus: sub,
        subscriptionExpiresAt: expiresAt,
      );
    } catch (_) {}
  }

  Future<void> register(String email, String password) async {
    final data = await ApiService.register(email, password);
    final token = data['access_token']?.toString() ?? '';
    final refreshToken = data['refresh_token']?.toString() ?? '';
    final userId = data['user']?['id']?.toString();
    ApiService.token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_emailKey, email);
    if (refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
    if (userId != null) await prefs.setString(_userIdKey, userId);

    state = AuthState(
      isLoggedIn: true,
      token: token,
      email: email,
      userId: userId,
    );

    try {
      final me = await ApiService.getMe();
      final meUserId = me['id']?.toString() ?? userId;
      final gems = (me['gems'] as num?)?.toInt() ?? 0;
      final sub = me['subscription_status']?.toString();
      final expiresAt = _parseExpiry(me);
      if (meUserId != null) await prefs.setString(_userIdKey, meUserId);
      state = state.copyWith(
        userId: meUserId, gems: gems, subscriptionStatus: sub,
        subscriptionExpiresAt: expiresAt,
      );
    } catch (_) {}
  }

  Future<void> refreshBalance() async {
    try {
      // /me/gems returns gems + subscription_status + subscription_expires_at
      // + subscription_active — richer than /auth/me for balance refreshes.
      final data = await ApiService.getGemsBalance();
      final gems = (data['gems'] as num?)?.toInt() ?? state.gems;
      final sub = data['subscription_status']?.toString() ?? state.subscriptionStatus;
      final expiresAt = _parseExpiry(data);
      state = state.copyWith(
        gems: gems,
        subscriptionStatus: sub,
        subscriptionExpiresAt: expiresAt,
      );
    } catch (e) {
      debugPrint('[refreshBalance] error: $e');
    }
  }

  static DateTime? _parseExpiry(Map<String, dynamic> me) {
    // Flat field — try every common naming variant
    final raw = me['subscription_expires_at']?.toString()
        ?? me['subscription_expiry']?.toString()
        ?? me['subscription_end_date']?.toString()
        ?? me['subscription_active_until']?.toString()
        ?? me['active_until']?.toString()
        ?? me['valid_until']?.toString()
        ?? me['expires_at']?.toString()
        ?? me['expiration_date']?.toString()
        ?? me['expiration_at']?.toString()
        ?? me['next_billing_date']?.toString()
        ?? me['paid_until']?.toString()
        ?? me['end_date']?.toString();

    if (raw != null) {
      // ISO-8601 string
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt != null) return dt;
      // Unix timestamp in seconds
      final ts = num.tryParse(raw);
      if (ts != null) {
        return DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000).toLocal();
      }
    }

    // Nested subscription object e.g. { "subscription": { "expires_at": "..." } }
    final sub = me['subscription'];
    if (sub is Map<String, dynamic>) {
      final subRaw = sub['expires_at']?.toString()
          ?? sub['expiry']?.toString()
          ?? sub['end_date']?.toString()
          ?? sub['active_until']?.toString()
          ?? sub['valid_until']?.toString()
          ?? sub['expiration_date']?.toString();
      if (subRaw != null) {
        final dt = DateTime.tryParse(subRaw)?.toLocal();
        if (dt != null) return dt;
        final ts = num.tryParse(subRaw);
        if (ts != null) {
          return DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000).toLocal();
        }
      }
    }

    debugPrint('[AuthNotifier] subscription expiry: not found. Available keys: ${me.keys.toList()}');
    return null;
  }

  void updateGems(int newBalance) {
    state = state.copyWith(gems: newBalance);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
  }

  Future<void> deleteAccount() async {
    await ApiService.deleteAccount();
    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
