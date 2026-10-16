import 'dart:math';

import 'package:flutter/material.dart';

import '../core/link_parser.dart';
import '../i18n.dart';
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
        final health = app.connHealth;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(children: [
                Image.asset('assets/logo.png', width: 40, height: 40),
                const SizedBox(width: 8),
                const GradientText('Aida VPN', size: 24),
                const Spacer(),
                Badge2(
                  vpn.ready ? 'Xray ${vpn.coreVersion}' : tr('آماده‌سازی هسته...', 'Starting core...'),
                  color: vpn.ready ? p.primary : Pal.warning,
                ),
              ]),
              const SizedBox(height: 22),
              const Center(child: ConnectButton()),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  vpn.connected
                      ? tr('متصل', 'Connected')
                      : (vpn.connecting ? tr('در حال اتصال...', 'Connecting...') : tr('قطع', 'Disconnected')),
                  style: TextStyle(
                    color: vpn.connected ? Pal.success : (vpn.connecting ? Pal.warning : p.sub),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              if (vpn.connected && health != null) ...[
                const SizedBox(height: 10),
                _HealthBanner(health: health),
              ],
              const SizedBox(height: 16),
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  Labeled(icon: Icons.timer_outlined, label: tr('مدت', 'Time'), value: vpn.connected ? st.duration : '00:00:00'),
                  Labeled(icon: Icons.south_rounded, label: tr('دانلود', 'Down'), value: fmtSpeed(st.downloadSpeed)),
                  Labeled(icon: Icons.north_rounded, label: tr('آپلود', 'Up'), value: fmtSpeed(st.uploadSpeed)),
                  Labeled(icon: Icons.data_usage_rounded, label: tr('مصرف', 'Usage'), value: fmtBytes(st.download + st.upload)),
                ]),
              ),
              SectionTitle(tr('کانفیگ انتخاب‌شده', 'Selected config')),
              if (c == null)
                Panel(
                  onTap: () => tabIndex.value = 1,
                  child: Row(children: [
                    Icon(Icons.add_circle_outline_rounded, color: p.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('هنوز کانفیگی ندارید؛ ایمپورت کنید یا کانفیگ رایگان بگیرید', 'No configs yet — import one or get free configs'),
                        style: TextStyle(color: p.sub),
                      ),
                    ),
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
                    Icon(forwardChevron, color: p.sub),
                  ]),
                ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (vpn.connected)
                  GhostButton(
                    label: tr('تست اتصال فعلی', 'Test connection'),
                    icon: Icons.speed_rounded,
                    onTap: () async {
                      final d = await app.checkConnection();
                      if (context.mounted) {
                        toast(context, d > 0 ? tr('تأخیر: $d ms', 'Latency: $d ms') : tr('اینترنت از این کانفیگ عبور نمی‌کند', 'No internet through this config'),
                            error: d <= 0);
                      }
                    },
                  )
                else if (c != null)
                  GhostButton(
                    label: tr('تست کانفیگ', 'Test config'),
                    icon: Icons.speed_rounded,
                    onTap: () => app.testConfigs([c]),
                  ),
              ]),
              SectionTitle(tr('دسترسی سریع', 'Quick actions')),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: [
                  _Quick(icon: Icons.card_giftcard_rounded, title: tr('کانفیگ رایگان', 'Free configs'), onTap: () => tabIndex.value = 2, gold: true),
                  _Quick(icon: Icons.content_paste_rounded, title: tr('از کلیپ‌بورد', 'From clipboard'), onTap: () => importFromClipboard(context)),
                  _Quick(icon: Icons.qr_code_scanner_rounded, title: tr('اسکن QR', 'Scan QR'), onTap: () => importFromQr(context)),
                  _Quick(
                    icon: app.testing ? Icons.stop_circle_outlined : Icons.speed_rounded,
                    title: app.testing ? '${num2(app.testDone)}/${num2(app.testTotal)}' : tr('تست همه', 'Test all'),
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

class _HealthBanner extends StatelessWidget {
  const _HealthBanner({required this.health});
  final int health;

  @override
  Widget build(BuildContext context) {
    final checking = health == 0;
    final ok = health > 0;
    final color = checking ? Pal.warning : (ok ? Pal.success : Pal.danger);
    final text = checking
        ? tr('در حال بررسی اینترنت...', 'Checking internet...')
        : ok
            ? tr('اینترنت برقرار است • $health ms', 'Internet OK • $health ms')
            : tr('وصل شد ولی اینترنت از این کانفیگ عبور نمی‌کند. کانفیگ دیگری انتخاب کنید.',
                'Connected, but no internet through this config. Pick another one.');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        if (checking)
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
        else
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
        if (!ok && !checking)
          TextButton(
            onPressed: () => tabIndex.value = 1,
            child: Text(tr('کانفیگ‌ها', 'Configs'), style: TextStyle(color: color)),
          ),
      ]),
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
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    app.vpn.addListener(_sync);
    _sync();
  }

  void _sync() {
    final active = app.vpn.connected || app.vpn.connecting;
    if (active && !_anim.isAnimating) _anim.repeat();
    if (!active && _anim.isAnimating) _anim.stop();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    app.vpn.removeListener(_sync);
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
                    Text(on ? tr('قطع', 'Stop') : tr('اتصال', 'Connect'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
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
