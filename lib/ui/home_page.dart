import 'dart:math';

import 'package:flutter/material.dart';

import '../core/link_parser.dart';
import '../store.dart';
import 'import_actions.dart';
import 'nav.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.vpn]),
      builder: (context, _) {
        final p = pal;
        final vpn = app.vpn;
        final c = app.selected;
        final st = vpn.status;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(children: [
                const GradientText('Aurum VPN', size: 26),
                const Spacer(),
                Badge2(vpn.ready ? 'Xray ${vpn.coreVersion}' : 'هسته در حال آماده‌سازی', color: vpn.ready ? p.primary : Pal.warning),
              ]),
              const SizedBox(height: 26),
              const Center(child: ConnectButton()),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  vpn.connected ? 'متصل و امن' : (vpn.connecting ? 'در حال اتصال...' : 'قطع'),
                  style: TextStyle(
                    color: vpn.connected ? Pal.success : (vpn.connecting ? Pal.warning : p.sub),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  Labeled(icon: Icons.timer_outlined, label: 'مدت', value: vpn.connected ? st.duration : '00:00:00'),
                  Labeled(icon: Icons.south_rounded, label: 'دانلود', value: fmtSpeed(st.downloadSpeed)),
                  Labeled(icon: Icons.north_rounded, label: 'آپلود', value: fmtSpeed(st.uploadSpeed)),
                  Labeled(icon: Icons.data_usage_rounded, label: 'مصرف', value: fmtBytes(st.download + st.upload)),
                ]),
              ),
              const SectionTitle('کانفیگ انتخاب‌شده'),
              if (c == null)
                Panel(
                  onTap: () => tabIndex.value = 1,
                  child: Row(children: [
                    Icon(Icons.add_circle_outline_rounded, color: p.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text('هنوز کانفیگی ندارید؛ ایمپورت کنید یا کانفیگ رایگان بگیرید', style: TextStyle(color: p.sub))),
                  ]),
                )
              else
                Panel(
                  highlight: true,
                  onTap: () => tabIndex.value = 1,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, children: [
                          Badge2(protocolLabel(c.protocol)),
                          Badge2(app.groupName(c.group), color: p.sub),
                        ]),
                      ]),
                    ),
                    DelayChip(delay: c.delay, tcp: c.tcpDelay, testing: app.testingIds.contains(c.id)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_left_rounded, color: p.sub),
                  ]),
                ),
              if (vpn.connected) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GhostButton(
                    label: 'تست پینگ اتصال فعلی',
                    icon: Icons.speed_rounded,
                    onTap: () async {
                      toast(context, 'در حال تست...');
                      final d = await vpn.connectedDelay(app.settings.testUrl);
                      if (context.mounted) toast(context, d > 0 ? 'تأخیر: $d ms' : 'تست ناموفق بود', error: d <= 0);
                    },
                  ),
                ),
              ],
              const SectionTitle('دسترسی سریع'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: [
                  _Quick(icon: Icons.card_giftcard_rounded, title: 'کانفیگ رایگان', onTap: () => tabIndex.value = 2, gold: true),
                  _Quick(icon: Icons.content_paste_rounded, title: 'از کلیپ‌بورد', onTap: () => importFromClipboard(context)),
                  _Quick(icon: Icons.qr_code_scanner_rounded, title: 'اسکن QR', onTap: () => importFromQr(context)),
                  _Quick(
                    icon: Icons.speed_rounded,
                    title: app.testing ? 'تست ${app.testDone}/${app.testTotal}' : 'تست همه',
                    onTap: () => app.testing ? app.cancelTest() : app.testConfigs(List.of(app.configs)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.title, required this.onTap, this.gold = false});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool gold;
  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      decoration: BoxDecoration(
        gradient: gold ? LinearGradient(colors: p.gradient) : null,
        color: gold ? null : p.surface,
        borderRadius: BorderRadius.circular(18),
        border: gold ? null : Border.all(color: p.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(icon, color: gold ? p.onPrimary : p.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: gold ? p.onPrimary : p.text, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key});
  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    final err = await app.toggleConnection();
    if (err != null && mounted) toast(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final vpn = app.vpn;
    final on = vpn.connected;
    final busy = vpn.connecting;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return SizedBox(
          width: 230,
          height: 230,
          child: Stack(alignment: Alignment.center, children: [
            if (on || busy)
              for (final k in [0.0, 0.5])
                Opacity(
                  opacity: (1 - ((t + k) % 1)) * 0.5,
                  child: Container(
                    width: 170 + 60 * ((t + k) % 1),
                    height: 170 + 60 * ((t + k) % 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: on ? p.primary : Pal.warning, width: 2),
                    ),
                  ),
                ),
            Transform.rotate(
              angle: busy ? t * 2 * pi : 0,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [...p.gradient, p.gradient.first]),
                ),
              ),
            ),
            Container(
              width: 166,
              height: 166,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surface,
                boxShadow: [
                  BoxShadow(color: p.primary.withValues(alpha: on ? 0.45 : 0.15), blurRadius: 40, spreadRadius: 2),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _tap,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ShaderMask(
                      shaderCallback: (r) => LinearGradient(colors: on ? p.gradient : [p.sub, p.sub]).createShader(r),
                      child: const Icon(Icons.power_settings_new_rounded, size: 72, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(on ? 'قطع' : 'اتصال', style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
