import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/link_parser.dart';
import '../core/pool.dart';
import '../models.dart';
import '../store.dart';
import 'cloudflare_api.dart';
import 'warp.dart';

/// Public config lists (checked to be live). Editable in settings.
const defaultFreeSources = [
  'https://raw.githubusercontent.com/barry-far/V2ray-Config/main/Sub1.txt',
  'https://raw.githubusercontent.com/Epodonios/v2ray-configs/main/Sub1.txt',
  'https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub1.txt',
  'https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/sub_merge.txt',
  'https://raw.githubusercontent.com/ALIILAPRO/v2rayNG-Config/main/sub.txt',
  'https://raw.githubusercontent.com/Kwinshadow/TelegramV2rayCollector/main/sublinks/mix.txt',
  'https://raw.githubusercontent.com/roosterkid/openproxylist/main/V2RAY_RAW.txt',
  'https://raw.githubusercontent.com/hans-thomas/v2ray-subscription/master/servers.txt',
  'https://raw.githubusercontent.com/4n0nymou3/multi-proxy-config-fetcher/main/configs/proxy_configs.txt',
];

/// raw.githubusercontent.com -> jsDelivr mirror (often reachable when raw is not).
String? _mirror(String url) {
  final m = RegExp(r'^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.+)$').firstMatch(url);
  if (m == null) return null;
  return 'https://cdn.jsdelivr.net/gh/${m[1]}/${m[2]}@${m[3]}/${m[4]}';
}

Future<String?> _fetchText(String url) async {
  for (final u in [url, _mirror(url)]) {
    if (u == null) continue;
    try {
      final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) return utf8.decode(r.bodyBytes, allowMalformed: true);
    } catch (_) {}
  }
  return null;
}

enum SlotState { building, ready }

/// Produces verified free configs as fast as possible: Cloudflare (WARP and
/// the user's own Worker) and public lists run in parallel; every candidate is
/// tested through the real core before it is accepted.
class FreeEngine extends ChangeNotifier {
  FreeEngine(this.app);
  final AppState app;

  static const cfTarget = 10;
  static const publicTarget = 20;

  bool running = false;
  bool _stop = false;
  List<VpnConfig?> cfSlots = List<VpnConfig?>.filled(cfTarget, null);
  List<VpnConfig> publicFound = [];
  String cfStage = '';
  String publicStage = '';
  int cfTested = 0;
  int publicTested = 0;
  int publicCandidates = 0;
  int sourcesOk = 0;
  final Stopwatch watch = Stopwatch();

  int get cfCount => cfSlots.whereType<VpnConfig>().length;
  bool get cfFull => cfCount >= cfTarget;
  bool get publicFull => publicFound.length >= publicTarget;

  void _notify() => notifyListeners();

  void _addCf(VpnConfig c) {
    if (cfFull) return;
    final i = cfSlots.indexOf(null);
    if (i < 0) return;
    c.group = Groups.freeCf;
    cfSlots[i] = c;
    app.addConfigs([c]);
    _notify();
  }

  void stop() {
    _stop = true;
    _notify();
  }

  Future<void> start() async {
    if (running) return;
    running = true;
    _stop = false;
    cfSlots = List<VpnConfig?>.filled(cfTarget, null);
    publicFound = [];
    cfTested = 0;
    publicTested = 0;
    publicCandidates = 0;
    sourcesOk = 0;
    cfStage = 'شروع...';
    publicStage = 'شروع...';
    watch
      ..reset()
      ..start();
    app.clearGroup(Groups.freeCf);
    app.clearGroup(Groups.freePublic);
    _notify();

    Future<void> guard(Future<void> Function() f, void Function(Object) onErr) async {
      try {
        await f();
      } catch (e) {
        onErr(e);
      }
    }

    await Future.wait([
      guard(_cloudflare, (e) => cfStage = 'خطا: $e'),
      guard(_public, (e) => publicStage = 'خطا: $e'),
    ]);

    watch.stop();
    running = false;
    await app.saveConfigs();
    _notify();
  }

  // ------------------------------------------------------------ Cloudflare

  Future<void> _cloudflare() async {
    final tokenAccs = app.accounts.where((a) => a.token.isNotEmpty || a.hasWorker).toList();
    final hasWorkerSide = tokenAccs.isNotEmpty;
    await Future.wait([
      _warp(cap: hasWorkerSide ? 5 : cfTarget),
      if (hasWorkerSide) _worker(tokenAccs),
    ]);
    if (!cfFull && !_stop) {
      await _warp(cap: cfTarget);
    }
    cfStage = cfFull
        ? '۱۰ کانفیگ کلودفلر ساخته و ایمپورت شد ✓'
        : (_stop ? 'متوقف شد' : '$cfCount کانفیگ سالم ساخته شد');
    _notify();
  }

  int _countWhere(String proto) => cfSlots.whereType<VpnConfig>().where((c) => c.protocol == proto).length;

  Future<WarpAccount?> _tryRegister() async {
    try {
      return await WarpService.register();
    } catch (_) {
      return null;
    }
  }

  Future<void> _warp({required int cap}) async {
    if (_stop || cfFull) return;
    cfStage = 'ثبت اکانت رایگان WARP ...';
    _notify();
    final fresh = (await Future.wait(List.generate(3, (_) => _tryRegister()))).whereType<WarpAccount>().toList();
    var accs = fresh;
    if (fresh.isNotEmpty) {
      await app.addWarps(fresh);
    } else {
      accs = app.warps;
    }
    if (accs.isEmpty) {
      cfStage = 'ثبت WARP ممکن نشد (API در دسترس نیست)';
      _notify();
      return;
    }
    for (var round = 0; round < 4; round++) {
      if (_stop || cfFull || _countWhere('wireguard') >= cap) break;
      cfStage = 'ساخت و تست کانفیگ‌های WARP (دور ${round + 1}) ...';
      _notify();
      final cands = <VpnConfig>[];
      for (var i = 0; i < 12; i++) {
        final link = WarpService.linkFor(
          accs[i % accs.length],
          ip: WarpService.randomEndpointIp(),
          port: WarpService.randomPort(),
          name: 'WARP',
        );
        final c = configFromLink(link, Groups.freeCf);
        if (c != null) cands.add(c);
      }
      await runPool<VpnConfig>(cands, 12, (c) async {
        final d = await app.realDelay(c);
        cfTested++;
        if (d > 0 && !cfFull && _countWhere('wireguard') < cap) {
          c.delay = d;
          c.name = '☁ WARP ${c.host}:${c.port}';
          _addCf(c);
        } else {
          _notify();
        }
      }, shouldStop: () => _stop || cfFull || _countWhere('wireguard') >= cap);
    }
  }

  Future<void> _worker(List<CfAccount> accs) async {
    // Deploy workers for tokens that do not have one yet.
    for (final a in accs.where((a) => !a.hasWorker && a.token.isNotEmpty)) {
      if (_stop) return;
      try {
        await CloudflareApi.setup(a, onStep: (s) {
          cfStage = '${a.label}: $s';
          _notify();
        });
        await app.upsertAccount(a);
        // New workers.dev routes need a few seconds to propagate.
        await Future.delayed(const Duration(seconds: 6));
      } catch (e) {
        a.status = 'invalid';
        await app.upsertAccount(a);
        cfStage = '${a.label}: $e';
        _notify();
      }
    }
    final hosts = accs.where((a) => a.hasWorker).toList();
    if (hosts.isEmpty) return;

    cfStage = 'اسکن آی‌پی تمیز کلودفلر ...';
    _notify();
    final userIps = app.settings.cleanIps
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final pool = [...userIps, ...randomCloudflareIps(90)];
    final scored = <MapEntry<String, int>>[];
    await runPool<String>(pool, 48, (ip) async {
      final t = await tcpPing(ip, 443, timeout: const Duration(milliseconds: 1500));
      if (t > 0) scored.add(MapEntry(ip, t));
    }, shouldStop: () => _stop);
    scored.sort((a, b) => a.value.compareTo(b.value));
    var ips = scored.map((e) => e.key).take(30).toList();
    if (ips.isEmpty) ips = pool.take(20).toList();

    const portCycle = [443, 8443, 2053, 2096, 80, 8080, 2083, 2087, 8880, 2052];
    final cands = <VpnConfig>[];
    for (var i = 0; i < ips.length; i++) {
      final a = hosts[i % hosts.length];
      final port = portCycle[i % portCycle.length];
      final link = buildWorkerVlessLink(
        uuid: a.workerUuid,
        host: a.workerHost,
        address: ips[i],
        port: port,
        name: 'Worker',
      );
      final c = configFromLink(link, Groups.freeCf);
      if (c != null) cands.add(c);
    }
    cfStage = 'تست کانفیگ‌های ورکر روی آی‌پی‌های تمیز ...';
    _notify();
    await runPool<VpnConfig>(cands, 12, (c) async {
      final d = await app.realDelay(c);
      cfTested++;
      if (d > 0 && !cfFull) {
        c.delay = d;
        c.name = '⚡ Worker ${c.host}:${c.port}';
        _addCf(c);
      } else {
        _notify();
      }
    }, shouldStop: () => _stop || cfFull);
  }

  // ------------------------------------------------------------ public lists

  Future<void> _public() async {
    final sources = app.settings.freeSources.trim().isEmpty
        ? defaultFreeSources
        : app.settings.freeSources.split(RegExp(r'[\r\n]+')).map((e) => e.trim()).where((e) => e.startsWith('http')).toList();
    publicStage = 'دریافت از ${sources.length} منبع به‌صورت موازی ...';
    _notify();
    final links = <String>{};
    await Future.wait(sources.map((u) async {
      final body = await _fetchText(u);
      if (body == null) return;
      sourcesOk++;
      links.addAll(extractLinks(body));
      _notify();
    }));
    if (_stop) return;

    final existing = app.configs.map((c) => c.dedupeKey).toSet();
    final seenHost = <String>{};
    final cands = <VpnConfig>[];
    for (final l in links) {
      final c = configFromLink(l, Groups.freePublic);
      if (c == null || existing.contains(c.dedupeKey)) continue;
      if (!seenHost.add('${c.host}:${c.port}')) continue;
      cands.add(c);
    }
    cands.shuffle();
    publicCandidates = cands.length;
    if (cands.isEmpty) {
      publicStage = sourcesOk == 0 ? 'منابع در دسترس نبودند' : 'کانفیگی پیدا نشد';
      _notify();
      return;
    }

    publicStage = 'فیلتر سریع ${cands.length} سرور (TCP) ...';
    _notify();
    final pre = cands.take(450).toList();
    final alive = <VpnConfig>[];
    await runPool<VpnConfig>(pre, 64, (c) async {
      if (isUdpTransport(c)) {
        alive.add(c);
        return;
      }
      final t = await tcpPing(c.host, c.port, timeout: const Duration(seconds: 2));
      if (t > 0) {
        c.tcpDelay = t;
        alive.add(c);
      }
    }, shouldStop: () => _stop);
    alive.sort((a, b) => (a.tcpDelay ?? 9999).compareTo(b.tcpDelay ?? 9999));

    publicStage = 'تست واقعی اتصال ${alive.length} سرور زنده ...';
    _notify();
    await runPool<VpnConfig>(alive.take(160).toList(), 12, (c) async {
      final d = await app.realDelay(c);
      publicTested++;
      if (d > 0 && !publicFull) {
        c.delay = d;
        c.group = Groups.freePublic;
        publicFound.add(c);
        app.addConfigs([c]);
      }
      _notify();
    }, shouldStop: () => _stop || publicFull);
    publicStage = publicFound.isEmpty ? 'هیچ سرور سالمی پیدا نشد' : '${publicFound.length} کانفیگ سالم تست و ایمپورت شد ✓';
    _notify();
  }
}
