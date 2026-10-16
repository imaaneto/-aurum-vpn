import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../store.dart';
import 'link_parser.dart';

/// HTTP for the app's own requests (sources, subscriptions, WARP, Cloudflare).
///
/// The VPN service excludes this app from the tunnel, so while connected the
/// app's own traffic would go out directly and hit the filter. To avoid that,
/// requests go through the core's local HTTP inbound when a connection is up.
class Net {
  /// [direct] skips the local proxy even while connected.
  static http.Client client({bool direct = false}) {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 5);
    if (!direct && app.vpn.connected) {
      final port = LocalProxy.httpPortFor(app.settings);
      // Credentials in the proxy string are sent pre-emptively, which also
      // covers HTTPS (CONNECT) requests.
      final cred = LocalProxy.authFor(app.settings) ? '${LocalProxy.user}:${LocalProxy.pass}@' : '';
      hc.findProxy = (_) => 'PROXY ${cred}127.0.0.1:$port';
    }
    return IOClient(hc);
  }

  /// Runs [fn] through the tunnel first (when connected) and falls back to a
  /// direct connection if that fails.
  static Future<T> _withFallback<T>(Future<T> Function(http.Client c) fn) async {
    final viaProxy = app.vpn.connected;
    final c = client();
    try {
      return await fn(c);
    } catch (e) {
      if (!viaProxy) rethrow;
    } finally {
      c.close();
    }
    final d = client(direct: true);
    try {
      return await fn(d);
    } finally {
      d.close();
    }
  }

  static Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _withFallback((c) => c.get(Uri.parse(url), headers: headers).timeout(timeout));

  static Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 20),
  }) =>
      _withFallback((c) => c.post(Uri.parse(url), headers: headers, body: body).timeout(timeout));

  /// [build] creates a fresh request for each attempt.
  static Future<http.Response> send(http.BaseRequest Function() build, {Duration timeout = const Duration(seconds: 30)}) =>
      _withFallback((c) async {
        final streamed = await c.send(build()).timeout(timeout);
        return http.Response.fromStream(streamed).timeout(timeout);
      });
}
