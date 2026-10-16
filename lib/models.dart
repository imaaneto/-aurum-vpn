import 'dart:math';

String newId() {
  final r = Random.secure();
  return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
}

/// Groups used for configs that do not belong to a subscription.
class Groups {
  static const manual = 'manual';
  static const freeCf = 'free_cf';
  static const freePublic = 'free_public';
}

class VpnConfig {
  VpnConfig({
    required this.id,
    required this.name,
    required this.link,
    required this.protocol,
    required this.host,
    required this.port,
    required this.group,
    this.delay,
    this.tcpDelay,
    this.addedAt = 0,
  });

  final String id;
  String name;

  /// Share link (vless://, vmess://, ...) or a raw Xray JSON config.
  final String link;
  final String protocol;
  final String host;
  final int port;

  /// Groups.* or a subscription id.
  String group;

  /// Real delay in ms. null = not tested, -1 = failed.
  int? delay;
  int? tcpDelay;
  int addedAt;

  bool get isJson => protocol == 'json';

  String get dedupeKey {
    if (isJson) return link.hashCode.toString();
    final hashIdx = link.indexOf('#');
    return hashIdx > 0 ? link.substring(0, hashIdx) : link;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'link': link,
        'protocol': protocol,
        'host': host,
        'port': port,
        'group': group,
        'delay': delay,
        'tcpDelay': tcpDelay,
        'addedAt': addedAt,
      };

  factory VpnConfig.fromJson(Map<String, dynamic> j) => VpnConfig(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        link: j['link'] as String,
        protocol: (j['protocol'] ?? '') as String,
        host: (j['host'] ?? '') as String,
        port: (j['port'] ?? 0) as int,
        group: (j['group'] ?? Groups.manual) as String,
        delay: j['delay'] as int?,
        tcpDelay: j['tcpDelay'] as int?,
        addedAt: (j['addedAt'] ?? 0) as int,
      );
}

class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.updatedAt = 0,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire = 0,
    this.lastError,
  });

  final String id;
  String name;
  String url;
  int updatedAt;
  int upload;
  int download;
  int total;
  int expire;
  String? lastError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'updatedAt': updatedAt,
        'upload': upload,
        'download': download,
        'total': total,
        'expire': expire,
        'lastError': lastError,
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        url: j['url'] as String,
        updatedAt: (j['updatedAt'] ?? 0) as int,
        upload: (j['upload'] ?? 0) as int,
        download: (j['download'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
        expire: (j['expire'] ?? 0) as int,
        lastError: j['lastError'] as String?,
      );
}

/// A Cloudflare API token (or a manually added worker) managed by the user.
class CfAccount {
  CfAccount({
    required this.id,
    required this.label,
    this.token = '',
    this.accountId = '',
    this.accountName = '',
    this.workerName = '',
    this.workerHost = '',
    this.workerUuid = '',
    this.proxyIp = '',
    this.status = 'unknown',
    this.createdAt = 0,
  });

  final String id;
  String label;
  String token;
  String accountId;
  String accountName;
  String workerName;
  String workerHost;
  String workerUuid;
  String proxyIp;

  /// unknown | active | invalid | manual
  String status;
  int createdAt;

  bool get isManual => token.isEmpty;
  bool get hasWorker => workerHost.isNotEmpty && workerUuid.isNotEmpty;

  String get maskedToken {
    if (token.length < 10) return token.isEmpty ? '—' : '••••';
    return '${token.substring(0, 4)}••••••${token.substring(token.length - 4)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'token': token,
        'accountId': accountId,
        'accountName': accountName,
        'workerName': workerName,
        'workerHost': workerHost,
        'workerUuid': workerUuid,
        'proxyIp': proxyIp,
        'status': status,
        'createdAt': createdAt,
      };

  factory CfAccount.fromJson(Map<String, dynamic> j) => CfAccount(
        id: j['id'] as String,
        label: (j['label'] ?? '') as String,
        token: (j['token'] ?? '') as String,
        accountId: (j['accountId'] ?? '') as String,
        accountName: (j['accountName'] ?? '') as String,
        workerName: (j['workerName'] ?? '') as String,
        workerHost: (j['workerHost'] ?? '') as String,
        workerUuid: (j['workerUuid'] ?? '') as String,
        proxyIp: (j['proxyIp'] ?? '') as String,
        status: (j['status'] ?? 'unknown') as String,
        createdAt: (j['createdAt'] ?? 0) as int,
      );
}

/// A registered Cloudflare WARP identity.
class WarpAccount {
  WarpAccount({
    required this.privateKey,
    required this.peerPublicKey,
    required this.v4,
    required this.v6,
    required this.reserved,
  });

  final String privateKey;
  final String peerPublicKey;
  final String v4;
  final String v6;
  final List<int> reserved;

  Map<String, dynamic> toJson() => {
        'privateKey': privateKey,
        'peerPublicKey': peerPublicKey,
        'v4': v4,
        'v6': v6,
        'reserved': reserved,
      };

  factory WarpAccount.fromJson(Map<String, dynamic> j) => WarpAccount(
        privateKey: j['privateKey'] as String,
        peerPublicKey: j['peerPublicKey'] as String,
        v4: j['v4'] as String,
        v6: (j['v6'] ?? '') as String,
        reserved: (j['reserved'] as List).map((e) => e as int).toList(),
      );
}

class AppSettings {
  AppSettings({
    this.darkGold = true,
    this.testUrl = 'https://www.gstatic.com/generate_204',
    this.testConcurrency = 10,
    this.dns = '1.1.1.1,8.8.8.8',
    this.proxyOnly = false,
    this.autoBest = false,
    this.blockedApps = '',
    this.cleanIps = '',
    this.freeSources = '',
    this.sniffing = true,
  });

  bool darkGold;
  String testUrl;
  int testConcurrency;
  String dns;
  bool proxyOnly;
  bool autoBest;
  String blockedApps;
  String cleanIps;

  /// newline separated; empty = use built-in defaults
  String freeSources;
  bool sniffing;

  Map<String, dynamic> toJson() => {
        'darkGold': darkGold,
        'testUrl': testUrl,
        'testConcurrency': testConcurrency,
        'dns': dns,
        'proxyOnly': proxyOnly,
        'autoBest': autoBest,
        'blockedApps': blockedApps,
        'cleanIps': cleanIps,
        'freeSources': freeSources,
        'sniffing': sniffing,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        darkGold: (j['darkGold'] ?? true) as bool,
        testUrl: (j['testUrl'] ?? 'https://www.gstatic.com/generate_204') as String,
        testConcurrency: (j['testConcurrency'] ?? 10) as int,
        dns: (j['dns'] ?? '1.1.1.1,8.8.8.8') as String,
        proxyOnly: (j['proxyOnly'] ?? false) as bool,
        autoBest: (j['autoBest'] ?? false) as bool,
        blockedApps: (j['blockedApps'] ?? '') as String,
        cleanIps: (j['cleanIps'] ?? '') as String,
        freeSources: (j['freeSources'] ?? '') as String,
        sniffing: (j['sniffing'] ?? true) as bool,
      );
}
