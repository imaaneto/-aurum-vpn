import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/link_parser.dart';
import '../core/net.dart';
import '../core/pool.dart';
import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import 'cloudflare_api.dart';
import 'warp.dart';

/// Public config lists (checked to be live). Editable in settings.
const defaultFreeSources = [
  'https://raw.githubusercontent.com/youfoundamin/V2rayCollector/main/mixed_iran.txt',
  'https://raw.githubusercontent.com/barry-far/V2ray-Config/main/Sub1.txt',
  'https://raw.githubusercontent.com/barry-far/V2ray-Config/main/Sub2.txt',
  'https://raw.githubusercontent.com/Epodonios/v2ray-configs/main/Sub1.txt',
  'https://raw.githubusercontent.com/Epodonios/v2ray-configs/main/Sub2.txt',
  'https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub1.txt',
  'https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub2.txt',
  'https://raw.githubusercontent.com/NiREvil/vless/main/sub/SSTime',
  'https://raw.githubusercontent.com/Rayan-Config/C-Sub/main/configs/proxy.txt',
  'https://raw.githubusercontent.com/arshiacomplus/v2rayExtractor/main/mix/sub.html',
  'https://raw.githubusercontent.com/V2RayRoot/V2RayConfig/main/Config/vless.txt',
  'https://raw.githubusercontent.com/Kwinshadow/TelegramV2rayCollector/main/sublinks/mix.txt',
  'https://raw.githubusercontent.com/roosterkid/openproxylist/main/V2RAY_RAW.txt',
  'https://raw.githubusercontent.com/hans-thomas/v2ray-subscription/master/servers.txt',
  'https://raw.githubusercontent.com/4n0nymou3/multi-proxy-config-fetcher/main/configs/proxy_configs.txt',
  'https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/sub_merge.txt',
];

/// Mirror URLs for a GitHub raw file; the first one to answer wins.
List<String> mirrorsFor(String url) {
  final m = RegExp(r'^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.+)$').firstMatch(url);
  if (m == null) return [url];
  final u = m[1], r = m[2], b = m[3], p = m[4];
  return [
    url,
    'https://fastly.jsdelivr.net/gh/$u/$r@$b/$p',
    'https://gcore.jsdelivr.net/gh/$u/$r@$b/$p',
    'https://cdn.jsdelivr.net/gh/$u/$r@$b/$p',
    'https://cdn.statically.io/gh/$u/$r/$b/$p',
  ];
}

/// Fetches a text file trying all mirrors at once; returns the first success.
Future<String?> fetchFast(String url) {
  final done = Completer<String?>();
  final urls = mirrorsFor(url);
  var pending = urls.length;
  for (final u in urls) {
    Net.get(u, timeout: const Duration(seconds: 14)).then((r) {
      if (!done.isCompleted && r.statusCode == 200 && r.bodyBytes.length > 20) {
        done.complete(utf8.decode(r.bodyBytes, allowMalformed: true));
      }
    }).catchError((Object _) {}).whenComplete(() {
      pending--;
      if (pending == 0 && !done.isCompleted) done.complete(null);
    });
  }
  return done.future;
}

/// One run of the engine. Stopping a run only flips this flag; late results
/// from a stopped run are ignored, so the UI is free immediately.
class _Run {
  bool stopped = false;
}

class FreeEngine extends ChangeNotifier {
  FreeEngine(this.app);
  final AppState app;

  static const cfTarget = 10;
  static const publicTarget = 20;

  _Run? _run;
  bool get running => _run != null && !_run!.stopped;

  List<VpnConfig?> cfSlots = List<VpnConfig?>.filled(cfTarget, null);
  List<VpnConfig> publicFound = [];
  String cfStage = '';
  String publicStage = '';
  int cfTested = 0;
  int publicTested = 0;
  int publicCandidates = 0;
  int tcpAlive = 0;
  int sourcesOk = 0;
  int sourcesTotal = 0;
  final List<String> log = [];
  final Stopwatch watch = Stopwatch();
  Timer? _ticker;

  int get cfCount => cfSlots.whereType<VpnConfig>().length;
  bool get cfFull => cfCount >= cfTarget;
  bool get publicFull => publicFound.length >= publicTarget;

  void _notify() => notifyListeners();

  void _log(_Run run, String s) {
    if (run.stopped) return;
    log.insert(0, s);
    if (log.length > 40) log.removeLast();
    _notify();
  }

  void _addCf(_Run run, VpnConfig c) {
    if (run.stopped || cfFull) return;
    final i = cfSlots.indexOf(null);
    if (i < 0) return;
    c.group = Groups.freeCf;
    cfSlots[i] = c;
    app.addConfigs([c]);
    _notify();
  }

  /// Stops instantly; anything still in flight is discarded.
  void stop() {
    final r = _run;
    if (r == null || r.stopped) return;
    r.stopped = true;
    watch.stop();
    _ticker?.cancel();
    if (!cfFull) cfStage = tr('متوقف شد', 'Stopped');
    if (!publicFull) publicStage = tr('متوقف شد', 'Stopped');
    app.saveConfigs();
    _notify();
  }

  Future<void> start() async {
    if (running) return;
    final run = _Run();
    _run = run;
    cfSlots = List<VpnConfig?>.filled(cfTarget, null);
    publicFound = [];
    cfTested = 0;
    publicTested = 0;
    publicCandidates = 0;
    tcpAlive = 0;
    sourcesOk = 0;
    sourcesTotal = 0;
    log.clear();
    cfStage = tr('شروع...', 'Starting...');
    publicStage = tr('شروع...', 'Starting...');
    watch
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    app.clearGroup(Groups.freeCf);
    app.clearGroup(Groups.freePublic);
    _notify();

    Future<void> guard(Future<void> Function() f, void Function(Object) onErr) async {
      try {
        await f();
      } catch (e) {
        if (!run.stopped) onErr(e);
      }
    }

    await Future.wait([
      guard(() => _cloudflare(run), (e) => cfStage = '${tr('خطا', 'Error')}: $e'),
      guard(() => _public(run), (e) => publicStage = '${tr('خطا', 'Error')}: $e'),
    ]);

    if (run.stopped) return;
    run.stopped = true;
    watch.stop();
    _ticker?.cancel();
    await app.saveConfigs();
    _notify();
  }

  // ------------------------------------------------------------ Cloudflare

  Future<void> _cloudflare(_Run run) async {
    final tokenAccs = app.accounts.where((a) => a.token.isNotEmpty || a.hasWorker).toList();
    final hasWorkerSide = tokenAccs.isNotEmpty;
    await Future.wait([
      _warp(run, cap: hasWorkerSide ? 5 : cfTarget),
      if (hasWorkerSide) _worker(run, tokenAccs),
    ]);
    // Top up with WARP only when WARP actually works on this network.
    if (!cfFull && !run.stopped && _countWhere('wireguard') > 0) {
      await _warp(run, cap: cfTarget, rounds: 2);
    }
    if (!run.stopped && cfCount == 0) {
      _log(run, tr('کلودفلر: روی این اینترنت WARP و ورکر جواب ندادند. اگر ورکر تازه ساخته شده، چند دقیقه بعد دوباره امتحان کنید.',
          'Cloudflare: neither WARP nor the worker answered on this network. If the worker is new, retry in a few minutes.'));
    }
    if (run.stopped) return;
    cfStage = cfFull
        ? tr('۱۰ کانفیگ کلودفلر ساخته و ایمپورت شد ✓', '10 Cloudflare configs built and imported ✓')
        : tr('${num2(cfCount)} کانفیگ سالم کلودفلر ساخته شد', '$cfCount working Cloudflare configs built');
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

  Future<void> _warp(_Run run, {required int cap, int rounds = 4}) async {
    if (run.stopped || cfFull) return;
    cfStage = tr('ثبت اکانت رایگان WARP ...', 'Registering free WARP accounts...');
    _notify();
    final fresh = (await Future.wait(List.generate(3, (_) => _tryRegister()))).whereType<WarpAccount>().toList();
    if (run.stopped) return;
    var accs = fresh;
    if (fresh.isNotEmpty) {
      await app.addWarps(fresh);
      _log(run, tr('WARP: ${num2(fresh.length)} اکانت جدید ثبت شد', 'WARP: ${fresh.length} new accounts registered'));
    } else {
      accs = app.warps;
      _log(run, tr('WARP: ثبت جدید ممکن نشد، از اکانت‌های ذخیره‌شده استفاده می‌شود', 'WARP: registration failed, using saved accounts'));
    }
    if (accs.isEmpty) {
      cfStage = tr('API ثبت WARP در دسترس نیست (فیلتر است)', 'WARP registration API is unreachable');
      _notify();
      return;
    }
    for (var round = 0; round < rounds; round++) {
      if (run.stopped || cfFull || _countWhere('wireguard') >= cap) break;
      cfStage = tr('تست اندپوینت‌های WARP (دور ${num2(round + 1)}) ...', 'Testing WARP endpoints (round ${round + 1})...');
      _notify();
      final cands = <VpnConfig>[];
      for (var i = 0; i < 16; i++) {
        final link = WarpService.linkFor(
          accs[i % accs.length],
          ip: WarpService.randomEndpointIp(),
          port: WarpService.randomPort(),
          name: 'WARP',
          noise: i.isEven,
        );
        final c = configFromLink(link, Groups.freeCf);
        if (c != null) cands.add(c);
      }
      await runPool<VpnConfig>(cands, 16, (c) async {
        final d = await app.realDelay(c, cancelled: () => run.stopped);
        if (run.stopped) return;
        cfTested++;
        if (d > 0 && !cfFull && _countWhere('wireguard') < cap) {
          c.delay = d;
          c.name = '☁ WARP${c.link.contains('aida_noise') ? '+noise' : ''} ${c.host}:${c.port}';
          _addCf(run, c);
          _log(run, 'WARP ✓ ${c.host}:${c.port}  ${d}ms');
        } else {
          _notify();
        }
      }, shouldStop: () => run.stopped || cfFull || _countWhere('wireguard') >= cap);
    }
  }

  Future<void> _worker(_Run run, List<CfAccount> accs) async {
    for (final a in accs.where((a) => !a.hasWorker && a.token.isNotEmpty)) {
      if (run.stopped) return;
      try {
        await CloudflareApi.setup(a, onStep: (s) {
          if (run.stopped) return;
          cfStage = '${a.label}: $s';
          _notify();
        });
        await app.upsertAccount(a);
        await Future.delayed(const Duration(seconds: 6));
      } catch (e) {
        a.status = 'invalid';
        a.lastError = '$e';
        await app.upsertAccount(a);
        _log(run, '${a.label}: $e');
      }
    }
    final hosts = accs.where((a) => a.hasWorker && !a.workerHost.contains('cloudflare.com')).toList();
    if (hosts.isEmpty || run.stopped) return;
    _log(run, tr('ورکرها: ${hosts.map((h) => h.workerHost).join('، ')}', 'Workers: ${hosts.map((h) => h.workerHost).join(', ')}'));

    cfStage = tr('اسکن آی‌پی تمیز کلودفلر ...', 'Scanning clean Cloudflare IPs...');
    _notify();
    final userIps = app.settings.cleanIps
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final pool = [...userIps, ...randomCloudflareIps(120)];
    final scored = <MapEntry<String, int>>[];
    await runPool<String>(pool, 60, (ip) async {
      final t = await tcpPing(ip, 443, timeout: const Duration(milliseconds: 1200));
      if (t > 0) scored.add(MapEntry(ip, t));
    }, shouldStop: () => run.stopped);
    if (run.stopped) return;
    scored.sort((a, b) => a.value.compareTo(b.value));
    var ips = scored.map((e) => e.key).take(30).toList();
    if (ips.isEmpty) ips = pool.take(20).toList();
    _log(run, tr('آی‌پی تمیز: ${num2(scored.length)} پاسخ داد', 'Clean IPs: ${scored.length} responded'));

    // TLS ports only: the core refuses plain VLESS to public addresses.
    const portCycle = [443, 8443, 2053, 2096, 2083, 2087];
    final cands = <VpnConfig>[];
    for (var i = 0; i < ips.length; i++) {
      final a = hosts[i % hosts.length];
      final link = buildWorkerVlessLink(
        uuid: a.workerUuid,
        host: a.workerHost,
        address: ips[i],
        port: portCycle[i % portCycle.length],
        name: 'Worker',
        fragment: i.isEven,
      );
      final c = configFromLink(link, Groups.freeCf);
      if (c != null) cands.add(c);
    }
    cfStage = tr('تست کانفیگ‌های ورکر ...', 'Testing worker configs...');
    _notify();
    await runPool<VpnConfig>(cands, 12, (c) async {
      final d = await app.realDelay(c, cancelled: () => run.stopped);
      if (run.stopped) return;
      cfTested++;
      if (d > 0 && !cfFull) {
        c.delay = d;
        c.name = '⚡ Worker${c.link.contains('aida_frag') ? '+frag' : ''} ${c.host}:${c.port}';
        _addCf(run, c);
        _log(run, 'Worker ✓ ${c.host}:${c.port}  ${d}ms');
      } else {
        _notify();
      }
    }, shouldStop: () => run.stopped || cfFull);
  }

  // ------------------------------------------------------------ public lists

  static int _protoRank(VpnConfig c) {
    switch (c.protocol) {
      case 'vless':
        return 0;
      case 'trojan':
        return 1;
      case 'hysteria2':
        return 2;
      case 'vmess':
        return 3;
      default:
        return 4;
    }
  }

  Future<void> _public(_Run run) async {
    final sources = app.settings.freeSources.trim().isEmpty
        ? defaultFreeSources
        : app.settings.freeSources
            .split(RegExp(r'[\r\n]+'))
            .map((e) => e.trim())
            .where((e) => e.startsWith('http'))
            .toList();
    sourcesTotal = sources.length;
    publicStage = tr('دریافت هم‌زمان از ${num2(sources.length)} منبع (با میرور) ...',
        'Fetching ${sources.length} sources in parallel (with mirrors)...');
    _notify();

    final existing = app.configs.map((c) => c.dedupeKey).toSet();
    final seenHost = <String>{};
    final queue = <VpnConfig>[];
    var producing = true;

    // Producer: every source, as soon as it arrives, is parsed and TCP-filtered
    // and the survivors are queued for the real test.
    Future<void> handleSource(String url) async {
      final body = await fetchFast(url);
      if (run.stopped) return;
      if (body == null) {
        _log(run, '✗ ${Uri.tryParse(url)?.pathSegments.take(2).join('/') ?? url}');
        return;
      }
      sourcesOk++;
      final cands = <VpnConfig>[];
      for (final l in extractLinks(body)) {
        final c = configFromLink(l, Groups.freePublic);
        if (c == null || existing.contains(c.dedupeKey)) continue;
        if (!seenHost.add('${c.host}:${c.port}')) continue;
        cands.add(c);
      }
      cands.shuffle();
      cands.sort((a, b) => _protoRank(a).compareTo(_protoRank(b)));
      final take = cands.take(120).toList();
      publicCandidates += cands.length;
      _log(run, tr('✓ منبع: ${num2(cands.length)} کانفیگ جدید', '✓ source: ${cands.length} new configs'));
      await runPool<VpnConfig>(take, 40, (c) async {
        if (isUdpTransport(c)) {
          queue.add(c);
          return;
        }
        final t = await tcpPing(c.host, c.port, timeout: const Duration(milliseconds: 1800));
        if (t > 0 && !run.stopped) {
          c.tcpDelay = t;
          tcpAlive++;
          queue.add(c);
        }
      }, shouldStop: () => run.stopped || publicFull);
    }

    final producer = Future.wait(sources.map(handleSource)).whenComplete(() => producing = false);

    publicStage = tr('تست واقعی اتصال سرورهای زنده ...', 'Real-testing live servers...');
    _notify();

    // Consumers: real core tests, fastest TCP first.
    Future<void> consumer() async {
      while (!run.stopped && !publicFull) {
        if (queue.isEmpty) {
          if (!producing) return;
          await Future.delayed(const Duration(milliseconds: 150));
          continue;
        }
        queue.sort((a, b) => (a.tcpDelay ?? 900).compareTo(b.tcpDelay ?? 900));
        final c = queue.removeAt(0);
        final d = await app.realDelay(c, cancelled: () => run.stopped || publicFull);
        if (run.stopped) return;
        publicTested++;
        if (d > 0 && !publicFull) {
          c.delay = d;
          c.group = Groups.freePublic;
          publicFound.add(c);
          app.addConfigs([c]);
          _log(run, '✓ ${protocolLabel(c.protocol)} ${c.host}  ${d}ms');
        }
        _notify();
      }
    }

    await Future.wait([producer, ...List.generate(app.settings.testConcurrency.clamp(4, 24).toInt(), (_) => consumer())]);
    if (run.stopped) return;
    if (publicFound.isNotEmpty) {
      publicStage = tr('${num2(publicFound.length)} کانفیگ سالم تست و ایمپورت شد ✓',
          '${publicFound.length} working configs tested and imported ✓');
    } else if (sourcesOk == 0) {
      publicStage = tr('هیچ منبعی در دسترس نبود؛ اینترنت یا فیلترینگ را بررسی کنید',
          'No source was reachable; check your internet');
    } else {
      publicStage = tr('سرور سالمی پیدا نشد؛ دوباره امتحان کنید', 'No working server found; try again');
    }
    _notify();
  }
}
