import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../models.dart';
import '../services/free_engine.dart';
import '../store.dart';
import 'nav.dart';
import 'theme.dart';
import 'widgets.dart';

final FreeEngine freeEngine = FreeEngine(app);

class FreePage extends StatelessWidget {
  const FreePage({super.key});

  Future<void> _connectBest(BuildContext context) async {
    final all = List<VpnConfig>.of(freeEngine.publicFound)
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
        final total = e.publicFound.length;
        final sources = e.sourcesTotal == 0 ? defaultFreeSources.length : e.sourcesTotal;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              GradientText(tr('کانفیگ رایگان', 'Free configs'), size: 24),
              const SizedBox(height: 6),
              Text(
                tr(
                  'با یک دکمه از ${num2(sources)} منبع عمومی به‌صورت موازی کانفیگ جمع می‌شود. هر کانفیگ قبل از افزودن با هسته Xray روی اینترنت خودتان واقعاً تست می‌شود.',
                  'One tap collects configs from $sources public sources in parallel. Every config is really tested with the Xray core on your own internet before it is added.',
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
              if (e.running || total > 0 || e.publicCandidates > 0) ...[
                const SizedBox(height: 12),
                Panel(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    Labeled(icon: Icons.source_rounded, label: tr('منبع', 'Sources'), value: '${e.sourcesOk}/${e.sourcesTotal}'),
                    Labeled(icon: Icons.inventory_2_outlined, label: tr('کاندید', 'Found'), value: '${e.publicCandidates}'),
                    Labeled(icon: Icons.wifi_tethering_rounded, label: tr('زنده', 'Alive'), value: '${e.tcpAlive}'),
                    Labeled(icon: Icons.science_outlined, label: tr('تست', 'Tested'), value: '${e.publicTested}'),
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
              SectionTitle('${tr('کانفیگ‌های سالم', 'Working configs')} (${num2(total)}/${num2(FreeEngine.publicTarget)})'),
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
