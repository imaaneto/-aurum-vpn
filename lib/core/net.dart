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
  static http.Client client() {
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 5);
    if (app.vpn.connected) {
      final port = LocalProxy.httpPortFor(app.settings);
      hc.findProxy = (_) => 'PROXY 127.0.0.1:$port';
      if (LocalProxy.authFor(app.settings)) {
        hc.addProxyCredentials('127.0.0.1', port, '', HttpClientBasicCredentials(LocalProxy.user, LocalProxy.pass));
        hc.authenticateProxy = (host, p, scheme, realm) async {
          hc.addProxyCredentials(host, p, realm ?? '', HttpClientBasicCredentials(LocalProxy.user, LocalProxy.pass));
          return true;
        };
      }
    }
    return IOClient(hc);
  }

  static Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final c = client();
    try {
      return await c.get(Uri.parse(url), headers: headers).timeout(timeout);
    } finally {
      c.close();
    }
  }

  static Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final c = client();
    try {
      return await c.post(Uri.parse(url), headers: headers, body: body).timeout(timeout);
    } finally {
      c.close();
    }
  }

  static Future<http.Response> send(http.BaseRequest req, {Duration timeout = const Duration(seconds: 30)}) async {
    final c = client();
    try {
      final streamed = await c.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } finally {
      c.close();
    }
  }
}
