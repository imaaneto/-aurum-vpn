import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import 'import_actions.dart';
import 'theme.dart';
import 'widgets.dart';

class ConfigsPage extends StatefulWidget {
  const ConfigsPage({super.key});
  @override
  State<ConfigsPage> createState() => _ConfigsPageState();
}

class _ConfigsPageState extends State<ConfigsPage> {
  String? _group; // null = all
  String _query = '';

  List<VpnConfig> get _visible {
    var l = app.inGroup(_group);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      l = l.where((c) => c.name.toLowerCase().contains(q) || c.host.toLowerCase().contains(q) || c.protocol.contains(q)).toList();
    }
    return l;
  }

  Future<void> _menu(String v) async {
    final list = _visible;
    switch (v) {
      case 'real':
        app.testConfigs(list);
        break;
      case 'tcp':
        app.testConfigs(list, real: false);
        break;
      case 'sort':
        app.sortByDelay();
        break;
      case 'failed':
        final n = app.removeFailed(list);
        toast(context, tr('${num2(n)} کانفیگ خراب حذف شد', '$n broken configs removed'));
        break;
      case 'dupes':
        final n = app.removeDuplicates();
        toast(context, tr('${num2(n)} تکراری حذف شد', '$n duplicates removed'));
        break;
      case 'export':
        await Clipboard.setData(ClipboardData(text: list.map((c) => c.link).join('\n')));
        if (mounted) toast(context, tr('${num2(list.length)} لینک کپی شد', '${list.length} links copied'));
        break;
      case 'clear':
        final label = _group == null ? tr('همه کانفیگ‌ها', 'all configs') : app.groupName(_group!);
        if (await confirm(context, tr('حذف', 'Delete'), tr('همه موارد «$label» حذف شوند؟', 'Delete everything in "$label"?'), ok: tr('حذف', 'Delete'))) {
          app.removeConfigs(list.map((e) => e.id).toList());
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.vpn]),
      builder: (context, _) {
        final p = pal;
        final groups = app.groups;
        if (_group != null && !groups.contains(_group)) _group = null;
        final list = _visible;
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            foregroundColor: p.text,
            surfaceTintColor: Colors.transparent,
            title: Text('${tr('کانفیگ‌ها', 'Configs')} (${num2(app.configs.length)})', style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                tooltip: tr('افزودن', 'Add'),
                icon: Icon(Icons.add_circle_rounded, color: p.primary, size: 30),
                onPressed: () => showImportSheet(context),
              ),
              PopupMenuButton<String>(
                color: p.surface,
                icon: Icon(Icons.tune_rounded, color: p.text),
                onSelected: _menu,
                itemBuilder: (_) => [
                  _mi('real', Icons.speed_rounded, tr('تست واقعی همه (موازی)', 'Real-test all (parallel)')),
                  _mi('tcp', Icons.network_ping_rounded, tr('پینگ TCP همه', 'TCP ping all')),
                  _mi('sort', Icons.sort_rounded, tr('مرتب‌سازی بر اساس سرعت', 'Sort by speed')),
                  _mi('failed', Icons.delete_sweep_rounded, tr('حذف کانفیگ‌های خراب', 'Remove failed configs')),
                  _mi('dupes', Icons.filter_alt_rounded, tr('حذف تکراری‌ها', 'Remove duplicates')),
                  _mi('export', Icons.ios_share_rounded, tr('کپی همه لینک‌ها', 'Copy all links')),
                  _mi('clear', Icons.delete_forever_rounded, tr('حذف همه موارد این بخش', 'Delete everything here')),
                ],
              ),
            ],
          ),
          body: Column(children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _chip(tr('همه', 'All'), null, app.configs.length),
                  for (final g in groups) _chip(app.groupName(g), g, app.inGroup(g).length),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: TextStyle(color: p.text),
                decoration: luxInput(tr('جستجو', 'Search'), suffix: Icon(Icons.search_rounded, color: p.sub)),
              ),
            ),
            if (app.testing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: app.testTotal == 0 ? null : app.testDone / app.testTotal,
                        minHeight: 8,
                        color: p.primary,
                        backgroundColor: p.surface2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${num2(app.testDone)}/${num2(app.testTotal)}', style: TextStyle(color: p.sub)),
                  TextButton(onPressed: app.cancelTest, child: Text(tr('توقف', 'Stop'), style: const TextStyle(color: Pal.danger))),
                ]),
              ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.layers_outlined,
                      title: tr('کانفیگی وجود ندارد', 'No configs'),
                      subtitle: tr('از کلیپ‌بورد، QR، ساب یا بخش کانفیگ رایگان اضافه کنید', 'Add from clipboard, QR, a subscription or the free section'),
                      action: LuxButton(label: tr('افزودن کانفیگ', 'Add config'), icon: Icons.add_rounded, expand: false, onTap: () => showImportSheet(context)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) => ConfigTile(c: list[i], showGroup: _group == null),
                    ),
            ),
          ]),
        );
      },
    );
  }

  Widget _chip(String label, String? g, int count) {
    final p = pal;
    final sel = _group == g;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text('$label  ${num2(count)}'),
        selected: sel,
        onSelected: (_) => setState(() => _group = g),
        selectedColor: p.primary,
        backgroundColor: p.surface2,
        side: BorderSide(color: sel ? p.primary : p.border),
        labelStyle: TextStyle(color: sel ? p.onPrimary : p.text, fontWeight: FontWeight.w700, fontSize: 12),
        showCheckmark: false,
      ),
    );
  }

  PopupMenuItem<String> _mi(String v, IconData i, String t) => PopupMenuItem(
        value: v,
        child: Row(children: [Icon(i, size: 18, color: pal.primary), const SizedBox(width: 10), Text(t, style: TextStyle(color: pal.text))]),
      );
}
