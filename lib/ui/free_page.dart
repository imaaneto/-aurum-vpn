import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/link_parser.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/free_engine.dart';
import '../store.dart';
import 'nav.dart';
import 'theme.dart';
import 'tokens_page.dart';
import 'widgets.dart';

final FreeEngine freeEngine = FreeEngine(app);

class FreePage extends StatelessWidget {
  const FreePage({super.key});

  Future<void> _connectBest(BuildContext context) async {
    final all = [...freeEngine.cfSlots.whereType<VpnConfig>(), ...freeEngine.publicFound]
      ..sort((a, b) => (a.delay ?? 99999).compareTo(b.delay ?? 99999));
    if (all.isEmpty) return;
    app.select(all.first.id);
    if (!app.vpn.connected) {
      final err = await app.connect();
      if (err != null && context.mounted) toast(context, err, error: true);
    }
    tabIndex.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([freeEngine, app, app.vpn]),
      builder: (context, _) {
        final p = pal;
        final e = freeEngine;
        final secs = e.watch.elapsed.inSeconds;
        final hasCf = app.accounts.isNotEmpty;
        final total = e.cfCount + e.publicFound.length;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              GradientText(tr('کانفیگ رایگان', 'Free configs'), size: 24),
              const SizedBox(height: 6),
              Text(
                tr(
                  'با یک دکمه: ساخت ۱۰ کانفیگ کلودفلر (WARP و ورکر اختصاصی شما) و جمع‌آوری از ${num2(defaultFreeSources.length)} منبع عمومی، '
                      'همه به‌صورت موازی. هر کانفیگ قبل از افزودن با هسته Xray واقعاً تست می‌شود.',
                  'One tap: build 10 Cloudflare configs (WARP and your own Worker) and collect from ${defaultFreeSources.length} public sources, '
                      'all in parallel. Every config is really tested with the Xray core before it is added.',
                ),
                style: TextStyle(color: p.sub, height: 1.7, fontSize: 13),
              ),
              const SizedBox(height: 16),
              e.running
                  ? LuxButton(
                      label: '${tr('توقف', 'Stop')} (${num2(secs)}${tr(' ثانیه', 's')})',
                      icon: Icons.stop_rounded,
                      danger: true,
                      onTap: e.stop,
                    )
                  : LuxButton(
                      label: tr('دریافت کانفیگ رایگان', 'Get free configs'),
                      icon: Icons.bolt_rounded,
                      onTap: app.vpn.ready ? () => e.start() : null,
                    ),
              if (!app.vpn.ready)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(tr('هسته Xray هنوز آماده نیست...', 'Xray core is not ready yet...'),
                      style: const TextStyle(color: Pal.warning, fontSize: 12)),
                ),
              if (e.running || total > 0) ...[
                const SizedBox(height: 12),
                Panel(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    Labeled(icon: Icons.source_rounded, label: tr('منبع', 'Sources'), value: '${e.sourcesOk}/${e.sourcesTotal}'),
                    Labeled(icon: Icons.inventory_2_outlined, label: tr('کاندید', 'Found'), value: '${e.publicCandidates}'),
                    Labeled(icon: Icons.wifi_tethering_rounded, label: tr('زنده', 'Alive'), value: '${e.tcpAlive}'),
                    Labeled(icon: Icons.science_outlined, label: tr('تست', 'Tested'), value: '${e.publicTested + e.cfTested}'),
                    Labeled(icon: Icons.verified_rounded, label: tr('سالم', 'Working'), value: '$total'),
                  ]),
                ),
              ],
              if (!e.running && total > 0) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text(
                      tr('${num2(total)} کانفیگ سالم در ${num2(secs)} ثانیه', '$total working configs in ${secs}s'),
                      style: const TextStyle(color: Pal.success, fontWeight: FontWeight.w700),
                    ),
                  ),
                  GhostButton(label: tr('اتصال به سریع‌ترین', 'Connect fastest'), icon: Icons.flash_on_rounded, onTap: () => _connectBest(context)),
                ]),
              ],
              SectionTitle(
                '${tr('کلودفلر', 'Cloudflare')} (${num2(e.cfCount)}/${num2(FreeEngine.cfTarget)})',
                trailing: GhostButton(
                  label: tr('مدیریت توکن', 'Tokens'),
                  icon: Icons.key_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TokensPage())),
                ),
              ),
              if (e.cfStage.isNotEmpty) _stage(e.cfStage, e.running),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: FreeEngine.cfTarget,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.3,
                ),
                itemBuilder: (_, i) => _Slot(index: i, config: e.cfSlots[i], running: e.running),
              ),
              if (!hasCf)
                Panel(
                  margin: const EdgeInsets.only(top: 12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TokensPage())),
                  child: Row(children: [
                    Icon(Icons.tips_and_updates_rounded, color: p.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          'برای کانفیگ VLESS اختصاصی روی ورکر کلودفلر (پایدارتر از WARP)، یک توکن کلودفلر اضافه کنید. رایگان است.',
                          'Add a Cloudflare token to get your own VLESS Worker configs (more reliable than WARP). It is free.',
                        ),
                        style: TextStyle(color: p.sub, fontSize: 12.5, height: 1.6),
                      ),
                    ),
                  ]),
                ),
              SectionTitle('${tr('منابع عمومی', 'Public sources')} (${num2(e.publicFound.length)}/${num2(FreeEngine.publicTarget)})'),
              if (e.publicStage.isNotEmpty) _stage(e.publicStage, e.running),
              for (final c in e.publicFound) ConfigTile(c: c),
              if (e.log.isNotEmpty) ...[
                SectionTitle(
                  tr('گزارش', 'Log'),
                  trailing: GhostButton(
                    label: tr('کپی', 'Copy'),
                    icon: Icons.copy_rounded,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: e.log.join('\n')));
                      toast(context, tr('گزارش کپی شد', 'Log copied'));
                    },
                  ),
                ),
                Panel(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final l in e.log.take(14))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(l, style: TextStyle(color: p.sub, fontSize: 11.5)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stage(String s, bool running) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          if (running)
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: pal.primary))
          else
            Icon(Icons.info_outline_rounded, size: 16, color: pal.sub),
          const SizedBox(width: 8),
          Expanded(child: Text(s, style: TextStyle(color: pal.sub, fontSize: 12.5))),
        ]),
      );
}

class _Slot extends StatelessWidget {
  const _Slot({required this.index, required this.config, required this.running});
  final int index;
  final VpnConfig? config;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final c = config;
    if (c == null) {
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          if (running)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
          else
            Icon(Icons.hourglass_empty_rounded, color: p.sub, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              running ? tr('در حال ساخت...', 'Building...') : '${tr('کانفیگ', 'Config')} ${num2(index + 1)}',
              style: TextStyle(color: p.sub, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );
    }
    final selected = app.selectedId == c.id;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [p.primary.withValues(alpha: 0.18), p.surface]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? p.primary : p.primary.withValues(alpha: 0.4), width: selected ? 1.8 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => app.select(c.id),
          onLongPress: () => showQrSheet(context, c.name, c.link),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                const Icon(Icons.check_circle_rounded, color: Pal.success, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(protocolLabel(c.protocol), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                Text('${c.delay}ms', style: TextStyle(color: delayColor(c.delay), fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Text('${c.host}:${c.port}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  textAlign: ltrValueAlign,
                  style: TextStyle(color: p.sub, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}
