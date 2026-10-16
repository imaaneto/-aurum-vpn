import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../core/link_parser.dart';
import '../core/net.dart';
import '../models.dart';

/// Free Cloudflare WARP (WireGuard) identities.
class WarpService {
  static const _api = 'https://api.cloudflareclient.com/v0a2158/reg';
  static const _defaultPeer = 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=';

  static const ports = [
    2408, 500, 1701, 4500, 854, 859, 864, 878, 880, 890, 891, 894, 903, 908,
    928, 934, 939, 942, 943, 945, 946, 955, 968, 987, 988, 1002, 1010, 1014,
    1018, 1070, 1074, 1180, 1387, 1843, 2371, 2506, 3138, 3476, 3581, 3854,
    4177, 4198, 4233, 5279, 5956, 7103, 7152, 7156, 7281, 7559, 8319, 8742,
    8854, 8886,
  ];

  static const _prefixes = [
    '162.159.192',
    '162.159.193',
    '162.159.195',
    '188.114.96',
    '188.114.97',
    '188.114.98',
    '188.114.99',
  ];

  /// Registers a new WARP device and returns its WireGuard identity.
  static Future<WarpAccount> register() async {
    final algo = X25519();
    final kp = await algo.newKeyPair();
    final priv = base64.encode(await kp.extractPrivateKeyBytes());
    final pub = base64.encode((await kp.extractPublicKey()).bytes);

    final body = jsonEncode({
      'key': pub,
      'install_id': '',
      'fcm_token': '',
      'tos': DateTime.now().toUtc().toIso8601String(),
      'model': 'PC',
      'serial_number': '',
      'locale': 'en_US',
    });
    final r = await Net.post(
      _api,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'User-Agent': 'okhttp/3.12.1',
        'CF-Client-Version': 'a-6.10-2158',
      },
      body: body,
      timeout: const Duration(seconds: 15),
    );
    if (r.statusCode != 200) {
      throw Exception('WARP HTTP ${r.statusCode}');
    }
    final j = (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>();
    final cfg = (j['config'] as Map).cast<String, dynamic>();
    final addrs = ((cfg['interface'] as Map)['addresses'] as Map).cast<String, dynamic>();
    final peers = (cfg['peers'] as List?) ?? const [];
    final peerKey = peers.isNotEmpty ? '${(peers.first as Map)['public_key'] ?? _defaultPeer}' : _defaultPeer;
    var reserved = <int>[0, 0, 0];
    final clientId = cfg['client_id'];
    if (clientId is String && clientId.isNotEmpty) {
      try {
        reserved = base64.decode(base64.normalize(clientId)).toList();
      } catch (_) {}
    }
    return WarpAccount(
      privateKey: priv,
      peerPublicKey: peerKey,
      v4: '${addrs['v4'] ?? '172.16.0.2'}',
      v6: '${addrs['v6'] ?? ''}',
      reserved: reserved,
    );
  }

  static String randomEndpointIp() {
    final r = Random.secure();
    return '${_prefixes[r.nextInt(_prefixes.length)]}.${1 + r.nextInt(254)}';
  }

  static int randomPort() => ports[Random.secure().nextInt(ports.length)];

  static String linkFor(WarpAccount a, {required String ip, required int port, required String name, bool noise = false}) {
    final l = buildWireguardLink(
      privateKey: a.privateKey,
      peerPublicKey: a.peerPublicKey,
      endpointHost: ip,
      endpointPort: port,
      addresses: [
        '${a.v4}/32',
        if (a.v6.isNotEmpty) '${a.v6}/128',
      ],
      reserved: a.reserved,
      mtu: 1280,
      name: name,
    );
    if (!noise) return l;
    final h = l.indexOf('#');
    return '${l.substring(0, h)}&aida_noise=1${l.substring(h)}';
  }
}
