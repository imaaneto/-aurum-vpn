import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/link_parser.dart';
import 'core/pool.dart';
import 'core/vpn_service.dart';
import 'i18n.dart';
import 'models.dart';
import 'services/subscription_service.dart';

class ImportResult {
  int added = 0;
  int duplicates = 0;
  int unsupported = 0;
  int subscriptions = 0;
  List<String> errors = [];

  String get summary {
    final parts = <String>[];
    if (added > 0) parts.add(tr('${num2(added)} کانفیگ اضافه شد', '$added configs added'));
    if (subscriptions > 0) parts.add(tr('${num2(subscriptions)} ساب اضافه شد', '$subscriptions subscriptions added'));
    if (duplicates > 0) parts.add(tr('${num2(duplicates)} تکراری', '$duplicates duplicates'));
    if (unsupported > 0) parts.add(tr('${num2(unsupported)} پشتیبانی‌نشده', '$unsupported unsupported'));
    if (errors.isNotEmpty) parts.add(errors.first);
    return parts.isEmpty ? tr('چیزی برای وارد کردن پیدا نشد', 'Nothing to import was found') : parts.join(' • ');
  }
}

bool isUdpTransport(VpnConfig c) {
  if (c.protocol == 'wireguard' || c.protocol.startsWith('hysteria')) return true;
  return transportLabel(c).startsWith('kcp') || transportLabel(c).contains('quic');
}

/// Global app state.
class AppState extends ChangeNotifier {
  final VpnService vpn = VpnService();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  List<VpnConfig> configs = [];
  List<Subscription> subs = [];
  List<CfAccount> accounts = [];
  List<WarpAccount> warps = [];
  AppSettings settings = AppSettings();
  String? selectedId;
  String? activeId;
  bool loaded = false;

  bool testing = false;
  int testDone = 0;
  int testTotal = 0;
  bool _cancelTest = false;
  final Set<String> testingIds = {};
  final Set<String> updatingSubs = {};
  late Semaphore coreLimiter = Semaphore(10);

  VpnConfig? get selected {
    for (final c in configs) {
      if (c.id == selectedId) return c;
    }
    return null;
  }

  VpnConfig? configById(String? id) {
    if (id == null) return null;
    for (final c in configs) {
      if (c.id == id) return c;
    }
    return null;
  }

  Subscription? subById(String id) {
    for (final s in subs) {
      if (s.id == id) return s;
    }
    return null;
  }

  String groupName(String g) {
    switch (g) {
      case Groups.manual:
        return tr('دستی', 'Manual');
      case Groups.freeCf:
        return tr('رایگان کلودفلر', 'Free Cloudflare');
      case Groups.freePublic:
        return tr('رایگان عمومی', 'Free public');
      default:
        return subById(g)?.name ?? tr('ساب', 'Subscription');
    }
  }

  List<String> get groups {
    final out = <String>[];
    for (final g in [Groups.manual, Groups.freeCf, Groups.freePublic]) {
      if (configs.any((c) => c.group == g)) out.add(g);
    }
    for (final s in subs) {
      out.add(s.id);
    }
    return out;
  }

  List<VpnConfig> inGroup(String? g) => g == null ? configs : configs.where((c) => c.group == g).toList();

  // ---------------------------------------------------------------- persistence

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    try {
      settings = AppSettings.fromJson((jsonDecode(p.getString('settings') ?? '{}') as Map).cast<String, dynamic>());
    } catch (_) {}
    coreLimiter = Semaphore(settings.testConcurrency.clamp(2, 32).toInt());
    try {
      configs = (jsonDecode(p.getString('configs') ?? '[]') as List)
          .map((e) => VpnConfig.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {}
    try {
      subs = (jsonDecode(p.getString('subs') ?? '[]') as List)
          .map((e) => Subscription.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {}
    try {
      warps = (jsonDecode(p.getString('warps') ?? '[]') as List)
          .map((e) => WarpAccount.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {}
    // Cloudflare features are disabled; drop configs they created earlier.
    configs.removeWhere((c) => c.group == Groups.freeCf);
    final sel = p.getString('selected');
    selectedId = (sel == null || sel.isEmpty) ? null : sel;
    try {
      final raw = await _secure.read(key: 'cf_accounts');
      if (raw != null) {
        accounts = (jsonDecode(raw) as List)
            .map((e) => CfAccount.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
    await vpn.init();
    notifyListeners();
  }

  Future<void> saveConfigs() async {
    await _prefs?.setString('configs', jsonEncode(configs.map((e) => e.toJson()).toList()));
    await _prefs?.setString('selected', selectedId ?? '');
  }

  Future<void> saveSubs() async {
    await _prefs?.setString('subs', jsonEncode(subs.map((e) => e.toJson()).toList()));
  }

  Future<void> saveSettings() async {
    coreLimiter.max = settings.testConcurrency.clamp(2, 32).toInt();
    await _prefs?.setString('settings', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> saveAccounts() async {
    await _secure.write(key: 'cf_accounts', value: jsonEncode(accounts.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> addWarps(List<WarpAccount> list) async {
    warps = [...list, ...warps].take(12).toList();
    await _prefs?.setString('warps', jsonEncode(warps.map((e) => e.toJson()).toList()));
  }

  // ---------------------------------------------------------------- configs

  /// Adds configs skipping duplicates. Returns how many were added.
  int addConfigs(List<VpnConfig> list, {bool save = true}) {
    final keys = configs.map((c) => c.dedupeKey).toSet();
    var added = 0;
    String? firstId;
    for (final c in list) {
      if (keys.add(c.dedupeKey)) {
        configs.add(c);
        firstId ??= c.id;
        added++;
      }
    }
    if (added > 0) {
      selectedId ??= firstId;
      if (save) saveConfigs();
      notifyListeners();
    }
    return added;
  }

  Future<ImportResult> importText(String text, {String group = Groups.manual}) async {
    final res = ImportResult();
    final t = text.trim();
    if (t.isEmpty) return res;
    final list = <VpnConfig>[];
    if (t.startsWith('{')) {
      final c = configFromJson(t, group);
      if (c != null) list.add(c);
    }
    final links = extractLinks(t);
    for (final l in links) {
      final c = configFromLink(l, group);
      if (c == null) {
        res.unsupported++;
      } else {
        list.add(c);
      }
    }
    if (list.isNotEmpty) {
      res.added = addConfigs(list);
      res.duplicates = list.length - res.added;
    }
    if (links.isEmpty && list.isEmpty) {
      for (final url in extractSubscriptionUrls(t)) {
        final err = await addSubscription('', url);
        res.subscriptions++;
        if (err != null) res.errors.add(err);
      }
    }
    return res;
  }

  void select(String id) {
    final changed = selectedId != id;
    selectedId = id;
    saveConfigs();
    notifyListeners();
    if (changed && (vpn.connected || vpn.connecting)) {
      reconnect();
    }
  }

  void removeConfigs(Iterable<String> ids) {
    final set = ids.toSet();
    configs.removeWhere((c) => set.contains(c.id));
    if (selectedId != null && set.contains(selectedId)) selectedId = configs.isEmpty ? null : configs.first.id;
    saveConfigs();
    notifyListeners();
  }

  void renameConfig(VpnConfig c, String name) {
    c.name = name;
    saveConfigs();
    notifyListeners();
  }

  /// Removes all configs of a group except the one in use.
  void clearGroup(String group, {bool keepSelected = true}) {
    configs.removeWhere((c) => c.group == group && !(keepSelected && (c.id == selectedId || c.id == activeId)));
    if (selected == null) selectedId = configs.isEmpty ? null : configs.first.id;
    saveConfigs();
    notifyListeners();
  }

  int removeDuplicates() {
    final seen = <String>{};
    final before = configs.length;
    configs = configs.where((c) => seen.add('${c.protocol}|${c.host}|${c.port}|${c.dedupeKey}')).toList();
    saveConfigs();
    notifyListeners();
    return before - configs.length;
  }

  int removeFailed(List<VpnConfig> scope) {
    final ids = scope.where((c) => c.delay == -1 && c.id != activeId).map((c) => c.id).toList();
    removeConfigs(ids);
    return ids.length;
  }

  void sortByDelay() {
    int key(VpnConfig c) => (c.delay == null || c.delay! < 0) ? 1 << 30 : c.delay!;
    configs.sort((a, b) => key(a).compareTo(key(b)));
    saveConfigs();
    notifyListeners();
  }

  // ---------------------------------------------------------------- testing

  /// Real delay through the core, limited app-wide.
  Future<int> realDelay(VpnConfig c, {bool Function()? cancelled}) async {
    String json;
    try {
      json = buildXrayJson(c, settings);
    } catch (_) {
      return -1;
    }
    return coreLimiter.run(() async {
      if (cancelled != null && cancelled()) return -1;
      return vpn.realDelay(json, settings.testUrl);
    });
  }

  Future<void> testConfigs(List<VpnConfig> list, {bool real = true}) async {
    if (testing || list.isEmpty) return;
    testing = true;
    _cancelTest = false;
    testDone = 0;
    testTotal = list.length;
    notifyListeners();
    await runPool<VpnConfig>(list, real ? settings.testConcurrency.clamp(2, 32).toInt() : 48, (c) async {
      testingIds.add(c.id);
      notifyListeners();
      if (real) {
        c.delay = await realDelay(c, cancelled: () => _cancelTest);
      } else {
        c.tcpDelay = isUdpTransport(c) ? null : await tcpPing(c.host, c.port);
      }
      testingIds.remove(c.id);
      testDone++;
      notifyListeners();
    }, shouldStop: () => _cancelTest);
    testing = false;
    testingIds.clear();
    await saveConfigs();
    notifyListeners();
  }

  void cancelTest() {
    _cancelTest = true;
  }

  // ---------------------------------------------------------------- connection

  Future<String?> toggleConnection() async {
    if (vpn.connected || vpn.connecting) {
      await vpn.stop();
      activeId = null;
      connHealth = null;
      notifyListeners();
      return null;
    }
    return connect();
  }

  Future<String?> connect() async {
    var c = selected;
    if (settings.autoBest) {
      final tested = configs.where((e) => (e.delay ?? -1) > 0).toList()
        ..sort((a, b) => a.delay!.compareTo(b.delay!));
      if (tested.isNotEmpty) {
        c = tested.first;
        selectedId = c.id;
      }
    }
    if (c == null) return tr('ابتدا یک کانفیگ انتخاب کنید', 'Select a config first');
    String json;
    try {
      json = buildXrayJson(c, settings);
    } catch (e) {
      return tr('کانفیگ نامعتبر است: ', 'Invalid config: ') + '$e';
    }
    activeId = c.id;
    notifyListeners();
    final apps = settings.blockedApps
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    connHealth = null;
    final err = await vpn.start(remark: c.name, json: json, proxyOnly: settings.proxyOnly, blockedApps: apps);
    if (err == null) _healthCheck(c);
    return err;
  }

  /// Result of the automatic check after connecting:
  /// null = not checked yet, 0 = checking, -1 = no internet through config, >0 = ms.
  int? connHealth;

  Future<void> _healthCheck(VpnConfig c) async {
    for (var i = 0; i < 30 && !vpn.connected; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!vpn.connected) return;
    connHealth = 0;
    notifyListeners();
    final d = await vpn.connectedDelay(settings.testUrl);
    if (activeId != c.id) return;
    connHealth = d;
    c.delay = d;
    notifyListeners();
    saveConfigs();
  }

  Future<int> checkConnection() async {
    connHealth = 0;
    notifyListeners();
    final d = await vpn.connectedDelay(settings.testUrl);
    connHealth = d;
    notifyListeners();
    return d;
  }

  Future<void> reconnect() async {
    await vpn.stop();
    await Future.delayed(const Duration(milliseconds: 600));
    await connect();
  }

  // ---------------------------------------------------------------- subscriptions

  Future<String?> addSubscription(String name, String url) async {
    final u = url.trim();
    if (subs.any((s) => s.url == u)) return tr('این ساب قبلاً اضافه شده', 'This subscription already exists');
    final s = Subscription(
      id: newId(),
      name: name.trim().isEmpty ? (Uri.tryParse(u)?.host ?? 'Sub') : name.trim(),
      url: u,
    );
    subs.add(s);
    await saveSubs();
    notifyListeners();
    return updateSubscription(s, autoName: name.trim().isEmpty);
  }

  Future<String?> updateSubscription(Subscription s, {bool autoName = false}) async {
    if (updatingSubs.contains(s.id)) return null;
    updatingSubs.add(s.id);
    notifyListeners();
    try {
      final r = await fetchSubscription(s.url);
      final fresh = <VpnConfig>[];
      final seen = <String>{};
      for (final l in r.links) {
        final c = configFromLink(l, s.id);
        if (c != null && seen.add(c.dedupeKey)) fresh.add(c);
      }
      if (fresh.isEmpty) throw Exception(tr('هیچ کانفیگ قابل‌استفاده‌ای در ساب پیدا نشد', 'No usable config found in this subscription'));
      final old = {for (final c in configs.where((c) => c.group == s.id)) c.dedupeKey: c};
      final selectedKey = configById(selectedId)?.group == s.id ? configById(selectedId)!.dedupeKey : null;
      for (final c in fresh) {
        final o = old[c.dedupeKey];
        if (o != null) {
          c.delay = o.delay;
          c.tcpDelay = o.tcpDelay;
        }
        if (selectedKey != null && c.dedupeKey == selectedKey) selectedId = c.id;
      }
      configs.removeWhere((c) => c.group == s.id);
      configs.addAll(fresh);
      selectedId ??= fresh.first.id;
      s
        ..upload = r.upload
        ..download = r.download
        ..total = r.total
        ..expire = r.expire
        ..updatedAt = DateTime.now().millisecondsSinceEpoch
        ..lastError = null;
      if (autoName && r.title != null && r.title!.trim().isNotEmpty) s.name = r.title!.trim();
      return null;
    } catch (e) {
      s.lastError = e.toString().replaceFirst('Exception: ', '');
      return s.lastError;
    } finally {
      updatingSubs.remove(s.id);
      await saveSubs();
      await saveConfigs();
      notifyListeners();
    }
  }

  Future<void> updateAllSubscriptions() async {
    await Future.wait(subs.map((s) => updateSubscription(s)));
  }

  Future<void> deleteSubscription(Subscription s) async {
    subs.removeWhere((e) => e.id == s.id);
    configs.removeWhere((c) => c.group == s.id && c.id != activeId);
    if (selected == null) selectedId = configs.isEmpty ? null : configs.first.id;
    await saveSubs();
    await saveConfigs();
    notifyListeners();
  }

  Future<void> editSubscription(Subscription s, String name, String url) async {
    s.name = name.trim().isEmpty ? s.name : name.trim();
    final changed = s.url != url.trim();
    s.url = url.trim();
    await saveSubs();
    notifyListeners();
    if (changed) await updateSubscription(s);
  }

  // ---------------------------------------------------------------- accounts

  Future<void> upsertAccount(CfAccount a) async {
    final i = accounts.indexWhere((e) => e.id == a.id);
    if (i >= 0) {
      accounts[i] = a;
    } else {
      accounts.add(a);
    }
    await saveAccounts();
  }

  Future<void> removeAccount(CfAccount a) async {
    accounts.removeWhere((e) => e.id == a.id);
    await saveAccounts();
  }
}

final AppState app = AppState();
