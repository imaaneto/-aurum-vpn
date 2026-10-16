import 'package:flutter/material.dart';

import '../services/free_engine.dart';
import '../store.dart';
import 'theme.dart';
import 'tokens_page.dart';
import 'widgets.dart';
import 'xdns_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.vpn]),
      builder: (context, _) {
        final p = pal;
        final s = app.settings;
        return SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
            const GradientText('تنظیمات', size: 24),
            const SectionTitle('تم'),
            Row(children: [
              Expanded(child: _ThemeCard(gold: true, selected: s.darkGold)),
              const SizedBox(width: 12),
              Expanded(child: _ThemeCard(gold: false, selected: !s.darkGold)),
            ]),
            const SectionTitle('اتصال'),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                _switch('فقط پروکسی (بدون VPN)', 'SOCKS روی 10808 و HTTP روی 10809', s.proxyOnly, (v) {
                  s.proxyOnly = v;
                  app.saveSettings();
                }),
                _switch('اتصال خودکار به سریع‌ترین', 'هنگام اتصال، کانفیگ با کمترین تأخیر انتخاب می‌شود', s.autoBest, (v) {
                  s.autoBest = v;
                  app.saveSettings();
                }),
                _switch('Sniffing', 'تشخیص دامنه از ترافیک (پیشنهادی)', s.sniffing, (v) {
                  s.sniffing = v;
                  app.saveSettings();
                }),
              ]),
            ),
            const SizedBox(height: 10),
            _field(context, 'DNS', s.dns, (v) => s.dns = v, hint: '1.1.1.1,8.8.8.8'),
            _field(context, 'آدرس تست تأخیر', s.testUrl, (v) => s.testUrl = v),
            _field(context, 'اپ‌هایی که از VPN عبور نکنند (Package name)', s.blockedApps, (v) => s.blockedApps = v,
                hint: 'com.example.app, ir.bank.app', lines: 3),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تعداد تست هم‌زمان: ${s.testConcurrency}', style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
                Slider(
                  value: s.testConcurrency.toDouble(),
                  min: 2,
                  max: 32,
                  divisions: 30,
                  activeColor: p.primary,
                  onChanged: (v) {
                    s.testConcurrency = v.round();
                    app.saveSettings();
                  },
                ),
                Text('عدد بالاتر = سریع‌تر، ولی مصرف رم بیشتر', style: TextStyle(color: p.sub, fontSize: 12)),
              ]),
            ),
            const SectionTitle('کانفیگ رایگان'),
            Panel(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TokensPage())),
              child: Row(children: [
                Icon(Icons.key_rounded, color: p.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('مدیریت توکن کلودفلر (${app.accounts.length})', style: TextStyle(color: p.text, fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_left_rounded, color: p.sub),
              ]),
            ),
            const SizedBox(height: 10),
            _field(context, 'آی‌پی‌های تمیز کلودفلر (اختیاری)', s.cleanIps, (v) => s.cleanIps = v,
                hint: 'هر آی‌پی در یک خط یا با کاما', lines: 3),
            _field(
              context,
              'منابع کانفیگ عمومی (خالی = پیش‌فرض)',
              s.freeSources,
              (v) => s.freeSources = v,
              hint: defaultFreeSources.first,
              lines: 4,
            ),
            const SectionTitle('ابزارها'),
            Panel(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const XdnsPage())),
              child: Row(children: [
                Icon(Icons.dns_rounded, color: p.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('سازنده DNS Tunnel (XDNS)', style: TextStyle(color: p.text, fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_left_rounded, color: p.sub),
              ]),
            ),
            const SectionTitle('درباره'),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aurum VPN 1.0.0', style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('هسته: Xray ${app.vpn.coreVersion.isEmpty ? '—' : app.vpn.coreVersion}', style: TextStyle(color: p.sub)),
                const SizedBox(height: 4),
                Text(
                  'پروتکل‌ها: VLESS (Reality, XTLS-Vision, WS, gRPC, XHTTP, HTTPUpgrade, mKCP)، VMess، Trojan، '
                  'Shadowsocks (+2022)، SOCKS، Hysteria2، WireGuard/WARP، XDNS و کانفیگ JSON کامل Xray',
                  style: TextStyle(color: p.sub, fontSize: 12, height: 1.7),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _switch(String t, String sub, bool v, ValueChanged<bool> f) => SwitchListTile(
        value: v,
        onChanged: f,
        activeColor: pal.primary,
        title: Text(t, style: TextStyle(color: pal.text, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(sub, style: TextStyle(color: pal.sub, fontSize: 12)),
      );

  Widget _field(BuildContext context, String label, String value, void Function(String) set, {String? hint, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () async {
          final v = await askText(context, title: label, label: label, initial: value, hint: hint, maxLines: lines);
          if (v == null) return;
          set(v.trim());
          await app.saveSettings();
        },
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: pal.text, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(value.isEmpty ? (hint ?? '—') : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: pal.sub, fontSize: 12)),
            ]),
          ),
          Icon(Icons.edit_rounded, size: 18, color: pal.sub),
        ]),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.gold, required this.selected});
  final bool gold;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final t = gold ? Pal.gold : Pal.navy;
    return GestureDetector(
      onTap: () {
        app.settings.darkGold = gold;
        app.saveSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 110,
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? pal.primary : pal.border, width: selected ? 2.4 : 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: t.gradient))),
            const SizedBox(width: 6),
            Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, color: t.surface, border: Border.all(color: t.border))),
            const Spacer(),
            if (selected) Icon(Icons.check_circle_rounded, color: t.primary),
          ]),
          const Spacer(),
          Text(gold ? 'مشکی طلایی' : 'سفید سرمه‌ای', style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
          Text(gold ? 'Black & Gold' : 'White & Navy', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
      ),
    );
  }
}
