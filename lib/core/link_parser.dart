import 'dart:convert';

import 'package:flutter_v2ray_client/flutter_v2ray.dart';

import '../models.dart';

/// Protocols the bundled Xray core can run.
const runnableProtocols = {
  'vless',
  'vmess',
  'trojan',
  'ss',
  'socks',
  'hysteria2',
  'hysteria',
  'wireguard',
  'json',
};

final RegExp _linkRe = RegExp(
  r'(?<![a-zA-Z0-9])(?:vless|vmess|trojan|hysteria2|hysteria|hy2|tuic|ss|socks5|socks|wireguard|wg)://[^\s<>"`]+',
  caseSensitive: false,
);

final RegExp _httpRe = RegExp(r'https?://[^\s<>"`]+', caseSensitive: false);

String? tryBase64(String input) {
  var t = input.trim().replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return null;
  t = t.replaceAll('-', '+').replaceAll('_', '/');
  t = t.replaceAll('=', '');
  final mod = t.length % 4;
  if (mod == 1) return null;
  if (mod > 0) t += '=' * (4 - mod);
  try {
    return utf8.decode(base64.decode(t), allowMalformed: true);
  } catch (_) {
    return null;
  }
}

// URL-safe alphabet: '/' would break URI authority parsing.
String _b64(String s) => base64Url.encode(utf8.encode(s));

String safeDecode(String s) {
  try {
    return Uri.decodeComponent(s.replaceAll('+', '%20'));
  } catch (_) {
    return s;
  }
}

String _cleanLink(String l) {
  var s = l.trim();
  while (s.isNotEmpty && ',;)]}\'\\'.contains(s[s.length - 1])) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Pulls every proxy share-link out of arbitrary text (subscription body,
/// clipboard, QR payload...). Handles base64 encoded bodies too.
List<String> extractLinks(String text) {
  var found = _linkRe.allMatches(text).map((m) => _cleanLink(m.group(0)!)).toList();
  if (found.isEmpty) {
    final decoded = tryBase64(text);
    if (decoded != null) {
      found = _linkRe.allMatches(decoded).map((m) => _cleanLink(m.group(0)!)).toList();
    }
  }
  // Some lists put a base64 blob per line.
  if (found.isEmpty) {
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final d = tryBase64(line);
      if (d == null) continue;
      found.addAll(_linkRe.allMatches(d).map((m) => _cleanLink(m.group(0)!)));
    }
  }
  return found;
}

/// http(s) URLs in a text that are not part of a proxy link -> subscriptions.
List<String> extractSubscriptionUrls(String text) {
  final stripped = text.replaceAll(_linkRe, ' ');
  return _httpRe.allMatches(stripped).map((m) => _cleanLink(m.group(0)!)).toSet().toList();
}

String normalizeScheme(String scheme) {
  switch (scheme.toLowerCase()) {
    case 'socks5':
      return 'socks';
    case 'hy2':
      return 'hysteria2';
    case 'wg':
      return 'wireguard';
    default:
      return scheme.toLowerCase();
  }
}

class _HostPort {
  _HostPort(this.host, this.port);
  final String host;
  final int port;
}

_HostPort? _hostPortFrom(String authority) {
  final at = authority.lastIndexOf('@');
  var hp = at >= 0 ? authority.substring(at + 1) : authority;
  final slash = hp.indexOf('/');
  if (slash >= 0) hp = hp.substring(0, slash);
  final q = hp.indexOf('?');
  if (q >= 0) hp = hp.substring(0, q);
  if (hp.startsWith('[')) {
    final end = hp.indexOf(']');
    if (end < 0) return null;
    final host = hp.substring(1, end);
    final port = int.tryParse(hp.substring(end + 1).replaceFirst(':', '')) ?? 443;
    return _HostPort(host, port);
  }
  final c = hp.lastIndexOf(':');
  if (c < 0) return _HostPort(hp, 443);
  return _HostPort(hp.substring(0, c), int.tryParse(hp.substring(c + 1)) ?? 443);
}

/// Splits "scheme://body#name" without relying on Uri (share links are often
/// not strictly valid URIs).
class _Parts {
  _Parts(this.scheme, this.body, this.name);
  final String scheme;
  final String body;
  final String name;

  String get authority {
    final q = body.indexOf('?');
    return q >= 0 ? body.substring(0, q) : body;
  }

  String get query {
    final q = body.indexOf('?');
    return q >= 0 ? body.substring(q + 1) : '';
  }

  Map<String, String> get params {
    final out = <String, String>{};
    for (final kv in query.split('&')) {
      if (kv.isEmpty) continue;
      final i = kv.indexOf('=');
      final k = i >= 0 ? kv.substring(0, i) : kv;
      final v = i >= 0 ? kv.substring(i + 1) : '';
      try {
        out[k] = Uri.decodeComponent(v);
      } catch (_) {
        out[k] = v;
      }
    }
    return out;
  }
}

_Parts? _split(String link) {
  final i = link.indexOf('://');
  if (i <= 0) return null;
  final scheme = link.substring(0, i);
  var rest = link.substring(i + 3);
  var name = '';
  final h = rest.indexOf('#');
  if (h >= 0) {
    name = safeDecode(rest.substring(h + 1));
    rest = rest.substring(0, h);
  }
  return _Parts(scheme, rest, name);
}

/// Makes legacy / non-standard links understandable by the core parser.
String normalizeLink(String link) {
  final p = _split(link);
  if (p == null) return link;
  final scheme = normalizeScheme(p.scheme);
  final frag = p.name.isEmpty ? '' : '#${Uri.encodeComponent(p.name)}';

  if (scheme == 'ss') {
    var auth = p.authority;
    final query = p.query.isEmpty ? '' : '?${p.query}';
    if (!auth.contains('@')) {
      // ss://BASE64(method:pass@host:port)
      final d = tryBase64(auth.replaceAll('/', ''));
      if (d != null && d.contains('@')) {
        final at = d.lastIndexOf('@');
        return 'ss://${_b64(d.substring(0, at))}@${d.substring(at + 1)}$query$frag';
      }
      return link;
    }
    final at = auth.lastIndexOf('@');
    final user = auth.substring(0, at);
    var hostPart = auth.substring(at + 1);
    if (hostPart.endsWith('/')) hostPart = hostPart.substring(0, hostPart.length - 1);
    final decodedUser = safeDecode(user);
    String methodPass;
    if (decodedUser.contains(':')) {
      methodPass = decodedUser; // SIP002 plain (2022 ciphers)
    } else {
      methodPass = tryBase64(user) ?? decodedUser;
    }
    return 'ss://${_b64(methodPass)}@$hostPart$query$frag';
  }

  if (scheme == 'socks') {
    final auth = p.authority;
    final query = p.query.isEmpty ? '' : '?${p.query}';
    if (!auth.contains('@')) return 'socks://$auth$query$frag';
    final at = auth.lastIndexOf('@');
    final rawUser = auth.substring(0, at);
    final user = safeDecode(rawUser);
    final userPass = user.contains(':') ? user : (tryBase64(rawUser) ?? user);
    return 'socks://${_b64(userPass)}@${auth.substring(at + 1)}$query$frag';
  }

  if (p.scheme != scheme) {
    return '$scheme://${p.body}$frag';
  }
  return link;
}

/// Builds a config entry (metadata only) from a share link.
VpnConfig? configFromLink(String raw, String group) {
  final link = raw.trim();
  final p = _split(link);
  if (p == null) return null;
  final proto = normalizeScheme(p.scheme);
  if (!runnableProtocols.contains(proto)) return null;

  var name = p.name;
  String host = '';
  int port = 0;

  if (proto == 'vmess') {
    final d = tryBase64(p.body.split('?').first);
    if (d == null) return null;
    try {
      final j = jsonDecode(d) as Map<String, dynamic>;
      host = '${j['add'] ?? ''}';
      port = int.tryParse('${j['port'] ?? ''}') ?? 0;
      if (name.isEmpty) name = '${j['ps'] ?? ''}';
    } catch (_) {
      return null;
    }
  } else if (proto == 'ss' && !p.authority.contains('@')) {
    final d = tryBase64(p.authority.replaceAll('/', ''));
    if (d == null || !d.contains('@')) return null;
    final hp = _hostPortFrom(d);
    if (hp == null) return null;
    host = hp.host;
    port = hp.port;
  } else {
    final hp = _hostPortFrom(p.authority);
    if (hp == null) return null;
    host = hp.host;
    port = hp.port;
  }
  if (host.isEmpty) return null;
  if (coreRejects(proto, link, host)) return null;
  if (name.trim().isEmpty) name = '${proto.toUpperCase()} $host';

  return VpnConfig(
    id: newId(),
    name: name.trim(),
    link: link,
    protocol: proto,
    host: host,
    port: port,
    group: group,
    addedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

bool _isPrivateHost(String h) {
  final x = h.toLowerCase();
  if (x == 'localhost' || x.endsWith('.local') || x.endsWith('.lan')) return true;
  return RegExp(r'^(10\.|127\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.|fc|fd|fe80)').hasMatch(x);
}

const _deadSsCiphers = {
  'aes-128-cfb', 'aes-192-cfb', 'aes-256-cfb', 'aes-128-ctr', 'aes-192-ctr', 'aes-256-ctr',
  'chacha20-ietf', 'chacha20', 'rc4-md5', 'rc4', 'bf-cfb', 'camellia-128-cfb', 'camellia-256-cfb',
  'salsa20', 'des-cfb', 'table',
};

/// True for configs the bundled Xray core refuses to load (checked against
/// the real core in CI): plain VLESS/Trojan to public hosts, legacy
/// Shadowsocks ciphers and the removed HTTP/2 transport.
bool coreRejects(String proto, String link, String host) {
  final p = _split(link);
  if (p == null) return true;
  if (proto == 'vless' || proto == 'trojan') {
    final q = p.params;
    final sec = (q['security'] ?? (proto == 'trojan' ? 'tls' : '')).toLowerCase();
    final enc = (q['encryption'] ?? 'none').toLowerCase();
    final secure = sec == 'tls' || sec == 'reality' || sec == 'xtls' || (proto == 'vless' && enc != 'none' && enc.isNotEmpty);
    if (!secure && !_isPrivateHost(host)) return true;
    final t = (q['type'] ?? '').toLowerCase();
    if (t == 'h2' || t == 'http') return true;
  }
  if (proto == 'vmess') {
    final d = tryBase64(p.body.split('?').first);
    if (d != null) {
      try {
        final j = jsonDecode(d) as Map;
        final net = '${j['net'] ?? ''}'.toLowerCase();
        if (net == 'h2' || net == 'http') return true;
      } catch (_) {}
    }
  }
  if (proto == 'ss') {
    final norm = normalizeLink(link);
    final np = _split(norm);
    if (np != null && np.authority.contains('@')) {
      final mp = tryBase64(np.authority.substring(0, np.authority.lastIndexOf('@'))) ?? '';
      final method = mp.split(':').first.toLowerCase();
      if (_deadSsCiphers.contains(method)) return true;
    }
  }
  return false;
}

/// A raw Xray JSON config pasted by the user.
VpnConfig? configFromJson(String text, String group) {
  try {
    final j = jsonDecode(text.trim());
    if (j is! Map || j['outbounds'] is! List) return null;
    final remarks = (j['remarks'] ?? 'Xray JSON').toString();
    var host = '';
    var port = 0;
    final ob = (j['outbounds'] as List).isEmpty ? null : (j['outbounds'] as List).first;
    if (ob is Map && ob['settings'] is Map) {
      final st = ob['settings'] as Map;
      final list = st['vnext'] ?? st['servers'];
      if (list is List && list.isNotEmpty && list.first is Map) {
        host = '${list.first['address'] ?? ''}';
        port = int.tryParse('${list.first['port'] ?? ''}') ?? 0;
      }
    }
    return VpnConfig(
      id: newId(),
      name: remarks,
      link: jsonEncode(j),
      protocol: 'json',
      host: host,
      port: port,
      group: group,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Xray JSON building
// ---------------------------------------------------------------------------

Map<String, dynamic> _wireguardOutbound(String link) {
  final p = _split(link)!;
  final auth = p.authority;
  final at = auth.lastIndexOf('@');
  final key = safeDecode(at >= 0 ? auth.substring(0, at) : '');
  final hp = _hostPortFrom(auth)!;
  final q = p.params;
  String fixB64(String? v) => (v ?? '').replaceAll(' ', '+');

  final addresses = (q['address'] ?? q['ip'] ?? '172.16.0.2/32')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => e.contains('/') ? e : (e.contains(':') ? '$e/128' : '$e/32'))
      .toList();

  List<int> reserved = [0, 0, 0];
  final r = q['reserved'];
  if (r != null && r.isNotEmpty) {
    if (r.contains(',')) {
      reserved = r.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    } else {
      try {
        reserved = base64.decode(base64.normalize(fixB64(r)));
      } catch (_) {}
    }
  }
  final endpoint = hp.host.contains(':') ? '[${hp.host}]:${hp.port}' : '${hp.host}:${hp.port}';

  return {
    'tag': 'proxy',
    'protocol': 'wireguard',
    'settings': {
      'secretKey': key.replaceAll(' ', '+'),
      'address': addresses,
      'peers': [
        {
          'publicKey': fixB64(q['publickey'] ?? q['publicKey'] ?? q['pbk']),
          'endpoint': endpoint,
          'allowedIPs': ['0.0.0.0/0', '::/0'],
          'keepAlive': 25,
        }
      ],
      'reserved': reserved,
      'mtu': int.tryParse(q['mtu'] ?? '') ?? 1280,
      // Hint read by the Android plugin to find the server address.
      'servers': [
        {'address': hp.host, 'port': hp.port}
      ],
    },
  };
}

List<String> _dnsList(AppSettings s) =>
    s.dns.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

const _privateCidrs = [
  '10.0.0.0/8',
  '172.16.0.0/12',
  '192.168.0.0/16',
  '127.0.0.0/8',
  '169.254.0.0/16',
  'fc00::/7',
  'fe80::/10',
];

/// The Android plugin reads outbounds[0].settings.vnext|servers[0].address.
void _ensureServerHint(Map<String, dynamic> ob) {
  final st = ob['settings'];
  if (st is! Map) {
    ob['settings'] = <String, dynamic>{
      'servers': [
        {'address': '127.0.0.1', 'port': 1}
      ]
    };
    return;
  }
  if (st['vnext'] is List && (st['vnext'] as List).isNotEmpty) return;
  if (st['servers'] is List && (st['servers'] as List).isNotEmpty) return;
  var addr = '${st['address'] ?? ''}';
  var port = int.tryParse('${st['port'] ?? ''}') ?? 443;
  if (addr.isEmpty && st['peers'] is List && (st['peers'] as List).isNotEmpty) {
    final hp = _hostPortFrom('${(st['peers'] as List).first['endpoint'] ?? ''}');
    if (hp != null) {
      addr = hp.host;
      port = hp.port;
    }
  }
  st['servers'] = [
    {'address': addr.isEmpty ? '127.0.0.1' : addr, 'port': port}
  ];
}

Map<String, String> _linkParams(String link) {
  final p = _split(link);
  if (p == null) return {};
  if (normalizeScheme(p.scheme) == 'vmess') {
    final d = tryBase64(p.body.split('?').first);
    if (d == null) return {};
    try {
      final j = jsonDecode(d) as Map;
      return {
        for (final e in j.entries) '${e.key}': '${e.value ?? ''}',
        'type': '${j['net'] ?? 'tcp'}',
      };
    } catch (_) {
      return {};
    }
  }
  return p.params;
}

void _applyExtras(Map<String, dynamic> ob, String link) {
  final q = _linkParams(link);
  final ss = (ob['streamSettings'] is Map)
      ? (ob['streamSettings'] as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  // Older parser quirks: list paths and the h2 key name.
  for (final key in ['wsSettings', 'xhttpSettings', 'httpSettings', 'h2Setting', 'httpupgradeSettings']) {
    final v = ss[key];
    if (v is Map && v['path'] is List) {
      final l = v['path'] as List;
      v['path'] = l.isEmpty ? '/' : '${l.first}';
    }
  }
  if (ss['h2Setting'] != null) {
    ss['httpSettings'] = ss.remove('h2Setting');
  }
  final type = q['type'] ?? '';
  if (type == 'httpupgrade' && ss['httpupgradeSettings'] == null) {
    ss['network'] = 'httpupgrade';
    ss['httpupgradeSettings'] = {
      'path': (q['path'] ?? '').isEmpty ? '/' : q['path'],
      'host': q['host'] ?? '',
    };
  }
  final fm = q['fm'];
  if (fm != null && fm.isNotEmpty && ss['finalmask'] == null) {
    try {
      ss['finalmask'] = jsonDecode(fm);
    } catch (_) {}
  }
  if (ss['network'] == 'kcp') {
    final k = (ss['kcpSettings'] is Map)
        ? (ss['kcpSettings'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final mtu = int.tryParse(q['mtu'] ?? '');
    final tti = int.tryParse(q['tti'] ?? '');
    if (mtu != null) k['mtu'] = mtu;
    if (tti != null) k['tti'] = tti;
    ss['kcpSettings'] = k;
  }
  if (ss.isNotEmpty) ob['streamSettings'] = ss;
}

Map<String, dynamic> _baseConfig(Map<String, dynamic> outbound, AppSettings s) => {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks',
          'port': 10808,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true, 'userLevel': 8},
          'sniffing': {
            'enabled': s.sniffing,
            'destOverride': ['http', 'tls', 'quic'],
            'routeOnly': true,
          },
        },
        {
          'tag': 'http',
          'port': 10809,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'settings': {'userLevel': 8},
        },
      ],
      'outbounds': [
        outbound,
        {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {},
        },
        {
          'tag': 'block',
          'protocol': 'blackhole',
          'settings': {},
        },
      ],
      'dns': {'servers': _dnsList(s)},
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {
            'type': 'field',
            'ip': _privateCidrs,
            'outboundTag': 'direct',
          },
        ],
      },
    };

/// Full Xray JSON for a config, ready for the core.
String buildXrayJson(VpnConfig c, AppSettings s) {
  Map<String, dynamic> full;
  if (c.isJson) {
    full = (jsonDecode(c.link) as Map).cast<String, dynamic>();
    final inb = full['inbounds'];
    if (inb is! List || !inb.any((e) => e is Map && e['protocol'] == 'socks')) {
      full['inbounds'] = [
        ...(inb is List ? inb : const []),
        {
          'tag': 'socks',
          'port': 10808,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true, 'userLevel': 8},
        },
      ];
    }
    final inb2 = full['inbounds'] as List;
    if (!inb2.any((e) => e is Map && e['protocol'] == 'http')) {
      full['inbounds'] = [
        ...inb2,
        {
          'tag': 'http',
          'port': 10809,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'settings': {'userLevel': 8},
        },
      ];
    }
    full['routing'] ??= {'domainStrategy': 'AsIs', 'rules': []};
    final obs = full['outbounds'] as List;
    if (obs.isNotEmpty && obs.first is Map) {
      _ensureServerHint((obs.first as Map).cast<String, dynamic>());
    }
    return jsonEncode(full);
  }

  Map<String, dynamic> outbound;
  if (c.protocol == 'wireguard') {
    outbound = _wireguardOutbound(c.link);
  } else {
    final normalized = normalizeLink(c.link);
    final parsed = V2ray.parseFromURL(normalized);
    final pj = (jsonDecode(parsed.getFullConfiguration()) as Map).cast<String, dynamic>();
    outbound = ((pj['outbounds'] as List).first as Map).cast<String, dynamic>();
    outbound['tag'] = 'proxy';
    _applyExtras(outbound, normalized);
  }
  _ensureServerHint(outbound);
  full = _baseConfig(outbound, s);
  return jsonEncode(full);
}

/// Returns null when the link is valid for the core, otherwise an error text.
String? validateConfig(VpnConfig c, AppSettings s) {
  try {
    buildXrayJson(c, s);
    return null;
  } catch (e) {
    return e.toString();
  }
}

// ---------------------------------------------------------------------------
// Link builders
// ---------------------------------------------------------------------------

String buildWireguardLink({
  required String privateKey,
  required String peerPublicKey,
  required String endpointHost,
  required int endpointPort,
  required List<String> addresses,
  required List<int> reserved,
  int mtu = 1280,
  required String name,
}) {
  final host = endpointHost.contains(':') ? '[$endpointHost]' : endpointHost;
  final q = [
    'address=${Uri.encodeComponent(addresses.join(','))}',
    'publickey=${Uri.encodeComponent(peerPublicKey)}',
    'reserved=${reserved.join(',')}',
    'mtu=$mtu',
  ].join('&');
  return 'wireguard://${Uri.encodeComponent(privateKey)}@$host:$endpointPort?$q#${Uri.encodeComponent(name)}';
}

/// XDNS (Xray's DNS tunnel, a modern DNSTT-style transport) over mKCP.
/// The core refuses plain VLESS to public addresses, so the tunnel uses
/// VMess, or VLESS when the server provides a VLESS encryption string.
String buildXdnsLink({
  required String uuid,
  required String domain,
  required String resolver,
  int resolverPort = 53,
  required String name,
  String protocol = 'vmess',
  String vlessEncryption = '',
}) {
  final fm = jsonEncode({
    'udp': [
      {
        'type': 'xdns',
        'settings': {
          'domains': [
            {
              'names': [domain],
              'types': [16],
            }
          ],
        },
      }
    ],
  });
  if (protocol == 'vless') {
    final q = [
      'encryption=${Uri.encodeComponent(vlessEncryption.isEmpty ? 'none' : vlessEncryption)}',
      'security=none',
      'type=kcp',
      'mtu=130',
      'tti=200',
      'fm=${Uri.encodeComponent(fm)}',
    ].join('&');
    return 'vless://$uuid@$resolver:$resolverPort?$q#${Uri.encodeComponent(name)}';
  }
  final vm = {
    'v': '2',
    'ps': name,
    'add': resolver,
    'port': '$resolverPort',
    'id': uuid,
    'aid': '0',
    'scy': 'auto',
    'net': 'kcp',
    'type': 'none',
    'tls': '',
    'fm': fm,
    'mtu': '130',
    'tti': '200',
  };
  return 'vmess://${base64.encode(utf8.encode(jsonEncode(vm)))}';
}

String protocolLabel(String p) {
  switch (p) {
    case 'vless':
      return 'VLESS';
    case 'vmess':
      return 'VMess';
    case 'trojan':
      return 'Trojan';
    case 'ss':
      return 'Shadowsocks';
    case 'socks':
      return 'SOCKS';
    case 'hysteria2':
      return 'Hysteria2';
    case 'hysteria':
      return 'Hysteria';
    case 'wireguard':
      return 'WireGuard';
    case 'json':
      return 'Xray JSON';
    default:
      return p.toUpperCase();
  }
}

/// Short transport description shown on config cards (ws/grpc/reality/...).
String transportLabel(VpnConfig c) {
  if (c.isJson || c.protocol == 'wireguard') return '';
  final p = _split(c.link);
  if (p == null) return '';
  if (c.protocol == 'vmess') {
    final d = tryBase64(p.body);
    if (d == null) return '';
    try {
      final j = jsonDecode(d) as Map;
      final tls = '${j['tls'] ?? ''}';
      return [j['net'] ?? 'tcp', if (tls.isNotEmpty) tls].join(' · ');
    } catch (_) {
      return '';
    }
  }
  final q = p.params;
  final parts = <String>[];
  if (q['type'] != null) parts.add(q['type']!);
  if ((q['security'] ?? '').isNotEmpty && q['security'] != 'none') parts.add(q['security']!);
  if (q['fm'] != null && q['fm']!.contains('xdns')) parts.add('XDNS');
  return parts.join(' · ');
}
