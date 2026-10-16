import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models.dart';

class CfException implements Exception {
  CfException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cloudflare REST API: token check, account lookup and Worker deployment.
class CloudflareApi {
  CloudflareApi(this.token);
  final String token;

  static const _base = 'https://api.cloudflare.com/client/v4';
  static const _timeout = Duration(seconds: 25);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> _decode(http.Response r) {
    Map<String, dynamic> j;
    try {
      j = (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      throw CfException('پاسخ نامعتبر از کلودفلر (HTTP ${r.statusCode})');
    }
    if (j['success'] != true) {
      final errs = (j['errors'] as List?) ?? const [];
      final msg = errs.isEmpty
          ? 'HTTP ${r.statusCode}'
          : errs.map((e) => e is Map ? '${e['code']}: ${e['message']}' : '$e').join(' | ');
      throw CfException(msg);
    }
    return j;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers).timeout(_timeout);
    return _decode(r);
  }

  Future<Map<String, dynamic>> _send(String method, String path, Object body) async {
    final req = http.Request(method, Uri.parse('$_base$path'))
      ..headers.addAll(_headers)
      ..body = jsonEncode(body);
    final r = await http.Response.fromStream(await req.send().timeout(_timeout));
    return _decode(r);
  }

  /// Returns (accountId, accountName) of the first account the token can see.
  Future<(String, String)> firstAccount() async {
    final j = await _get('/accounts?per_page=5');
    final list = (j['result'] as List?) ?? const [];
    if (list.isEmpty) {
      throw CfException('این توکن به هیچ اکانتی دسترسی ندارد');
    }
    final a = list.first as Map;
    return ('${a['id']}', '${a['name'] ?? ''}');
  }

  Future<String> accountName(String accountId) async {
    final j = await _get('/accounts/$accountId');
    return '${(j['result'] as Map?)?['name'] ?? ''}';
  }

  /// workers.dev subdomain of the account; creates one if missing.
  Future<String> ensureSubdomain(String accountId) async {
    try {
      final j = await _get('/accounts/$accountId/workers/subdomain');
      final sub = '${(j['result'] as Map?)?['subdomain'] ?? ''}';
      if (sub.isNotEmpty) return sub;
    } catch (_) {}
    final name = 'aurum${_randHex(6)}';
    final j = await _send('PUT', '/accounts/$accountId/workers/subdomain', {'subdomain': name});
    return '${(j['result'] as Map?)?['subdomain'] ?? name}';
  }

  /// Uploads the VLESS worker and enables its workers.dev route.
  Future<void> deployWorker({
    required String accountId,
    required String scriptName,
    required String uuid,
    String proxyIp = '',
  }) async {
    final template = await rootBundle.loadString('assets/worker.js');
    final script = template.replaceAll('__UUID__', uuid).replaceAll('__PROXYIP__', proxyIp);
    final req = http.MultipartRequest(
      'PUT',
      Uri.parse('$_base/accounts/$accountId/workers/scripts/$scriptName'),
    )..headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromString(
      'metadata',
      jsonEncode({
        'main_module': 'worker.js',
        'compatibility_date': '2024-09-23',
      }),
      contentType: MediaType('application', 'json'),
    ));
    req.files.add(http.MultipartFile.fromString(
      'worker.js',
      script,
      filename: 'worker.js',
      contentType: MediaType('application', 'javascript+module'),
    ));
    final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 40)));
    _decode(r);
    await _send('POST', '/accounts/$accountId/workers/scripts/$scriptName/subdomain', {
      'enabled': true,
      'previews_enabled': false,
    });
  }

  Future<void> deleteWorker(String accountId, String scriptName) async {
    final r = await http
        .delete(Uri.parse('$_base/accounts/$accountId/workers/scripts/$scriptName?force=true'), headers: _headers)
        .timeout(_timeout);
    _decode(r);
  }

  /// Full setup used by the token manager: verifies the token, finds the
  /// account and deploys a fresh worker. Mutates and returns [acc].
  static Future<CfAccount> setup(CfAccount acc, {void Function(String)? onStep}) async {
    final api = CloudflareApi(acc.token);
    onStep?.call('بررسی توکن...');
    if (acc.accountId.isEmpty) {
      final (id, name) = await api.firstAccount();
      acc.accountId = id;
      acc.accountName = name;
    } else if (acc.accountName.isEmpty) {
      try {
        acc.accountName = await api.accountName(acc.accountId);
      } catch (_) {}
    }
    onStep?.call('آماده‌سازی دامنه workers.dev ...');
    final sub = await api.ensureSubdomain(acc.accountId);
    final scriptName = acc.workerName.isNotEmpty ? acc.workerName : 'aurum-${_randHex(6)}';
    final uuid = acc.workerUuid.isNotEmpty ? acc.workerUuid : randomUuid();
    onStep?.call('ساخت ورکر $scriptName ...');
    await api.deployWorker(
      accountId: acc.accountId,
      scriptName: scriptName,
      uuid: uuid,
      proxyIp: acc.proxyIp,
    );
    acc.workerName = scriptName;
    acc.workerUuid = uuid;
    acc.workerHost = '$scriptName.$sub.workers.dev';
    acc.status = 'active';
    onStep?.call('ورکر ساخته شد');
    return acc;
  }
}

String _randHex(int n) {
  final r = Random.secure();
  return List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
}

String randomUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

// ---------------------------------------------------------------------------
// Clean Cloudflare edge IPs
// ---------------------------------------------------------------------------

const _cfRanges = [
  [104, 16, 31],
  [172, 64, 71],
  [162, 159, 159],
  [188, 114, 99],
  [108, 162, 255],
  [141, 101, 127],
];

/// Random IPs from Cloudflare's anycast ranges.
List<String> randomCloudflareIps(int count) {
  final r = Random.secure();
  final out = <String>{};
  while (out.length < count) {
    final range = _cfRanges[r.nextInt(_cfRanges.length)];
    int second;
    if (range[0] == 188) {
      second = 96 + r.nextInt(4);
    } else if (range[0] == 108) {
      second = 162;
    } else if (range[0] == 141) {
      second = 101;
    } else {
      second = range[1] + r.nextInt(range[2] - range[1] + 1);
    }
    int third = r.nextInt(256);
    if (range[0] == 108) third = 192 + r.nextInt(64);
    if (range[0] == 141) third = 64 + r.nextInt(64);
    out.add('${range[0]}.$second.$third.${1 + r.nextInt(254)}');
  }
  return out.toList();
}

const workerTlsPorts = [443, 8443, 2053, 2083, 2087, 2096];
const workerPlainPorts = [80, 8080, 8880, 2052, 2082, 2086, 2095];

String buildWorkerVlessLink({
  required String uuid,
  required String host,
  required String address,
  required int port,
  required String name,
}) {
  final tls = workerTlsPorts.contains(port);
  final q = <String>[
    'encryption=none',
    'type=ws',
    'host=$host',
    'path=${Uri.encodeComponent('/?ed=2048')}',
    if (tls) ...['security=tls', 'sni=$host', 'fp=chrome', 'alpn=http%2F1.1'] else 'security=none',
  ].join('&');
  final addr = address.contains(':') ? '[$address]' : address;
  return 'vless://$uuid@$addr:$port?$q#${Uri.encodeComponent(name)}';
}
