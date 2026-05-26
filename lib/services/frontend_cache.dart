import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

class FrontendCache {
  FrontendCache._();

  static const Duration defaultTtl = Duration(minutes: 5);
  static const int maxEntries = 300;
  static final Map<String, _HttpCacheEntry> _httpEntries = {};
  static final Map<String, Future<http.Response>> _httpPending = {};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static int _version = 0;
  static bool _revisionNotifyScheduled = false;

  static Future<http.Response> httpGet({
    required String key,
    required Future<http.Response> Function() request,
    Duration ttl = defaultTtl,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cached = _httpEntries[key];

    if (!forceRefresh && cached != null && now.difference(cached.savedAt) < ttl) {
      _refreshInBackground(key: key, request: request);
      return cached.toResponse();
    }

    if (!forceRefresh && _httpPending.containsKey(key)) {
      return _httpPending[key]!;
    }

    final requestVersion = _version;

    final future = request().then((response) {
      if (requestVersion == _version &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        _httpEntries[key] = _HttpCacheEntry.fromResponse(response);
        _pruneIfNeeded();
      }
      return response;
    }).whenComplete(() {
      _httpPending.remove(key);
    });

    _httpPending[key] = future;
    return future;
  }

  static void invalidateAll() {
    _version++;
    _httpEntries.clear();
    _httpPending.clear();
  }

  static void invalidateWhere(bool Function(String key) test) {
    _version++;
    _httpEntries.removeWhere((key, _) => test(key));
    _httpPending.removeWhere((key, _) => test(key));
  }

  static void _pruneIfNeeded() {
    if (_httpEntries.length <= maxEntries) return;

    final entries = _httpEntries.entries.toList()
      ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));

    final removeCount = _httpEntries.length - maxEntries;
    for (final entry in entries.take(removeCount)) {
      _httpEntries.remove(entry.key);
    }
  }

  static void _refreshInBackground({
    required String key,
    required Future<http.Response> Function() request,
  }) {
    if (_httpPending.containsKey(key)) return;

    final requestVersion = _version;
    final future = request().then((response) {
      if (requestVersion != _version ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return response;
      }

      final previous = _httpEntries[key];
      final next = _HttpCacheEntry.fromResponse(response);
      if (previous == null || !previous.samePayload(next)) {
        _httpEntries[key] = next;
        _pruneIfNeeded();
        _notifyRevisionChanged();
      } else {
        _httpEntries[key] = next;
      }

      return response;
    }).catchError((Object _) {
      return http.Response('', 599);
    }).whenComplete(() {
      _httpPending.remove(key);
    });

    _httpPending[key] = future;
  }

  static void _notifyRevisionChanged() {
    if (_revisionNotifyScheduled) return;
    _revisionNotifyScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _revisionNotifyScheduled = false;
      revision.value++;
    });
  }
}

class _HttpCacheEntry {
  final int statusCode;
  final List<int> bodyBytes;
  final Map<String, String> headers;
  final DateTime savedAt;

  const _HttpCacheEntry({
    required this.statusCode,
    required this.bodyBytes,
    required this.headers,
    required this.savedAt,
  });

  factory _HttpCacheEntry.fromResponse(http.Response response) {
    return _HttpCacheEntry(
      statusCode: response.statusCode,
      bodyBytes: List<int>.from(response.bodyBytes),
      headers: Map<String, String>.from(response.headers),
      savedAt: DateTime.now(),
    );
  }

  http.Response toResponse() {
    return http.Response.bytes(
      List<int>.from(bodyBytes),
      statusCode,
      headers: Map<String, String>.from(headers),
    );
  }

  bool samePayload(_HttpCacheEntry other) {
    if (statusCode != other.statusCode ||
        bodyBytes.length != other.bodyBytes.length) {
      return false;
    }

    for (var i = 0; i < bodyBytes.length; i++) {
      if (bodyBytes[i] != other.bodyBytes[i]) return false;
    }

    return true;
  }
}
