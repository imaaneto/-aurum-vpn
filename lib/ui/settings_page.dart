import 'package:flutter/material.dart';

import '../i18n.dart';
import '../services/free_engine.dart';
import '../store.dart';
import 'logs_page.dart';
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
            GradientText(tr('تنظیمات', 'Settings'), size: 24),
            SectionTitle(tr('زبان', 'Language')),
            Row(children: [
              Expanded(child: _LangCard(code: 'fa', label: 'فارسی', selected: appLang == 'fa')),
              const SizedBox(width: 12),
              Expanded(child: _LangCard(code: 'en', label: 'English', selected: appLang == 'en')),
            ]),
            SectionTitle(tr('تم', 'Theme')),
            Row(children: [
              Expanded(child: _ThemeCard(gold: true, selected: s.darkGold)),
              const SizedBox(width: 12),
              Expanded(child: _ThemeCard(gold: false, selected: !s.darkGold)),
            ]),
            SectionTitle(tr('اتصال', 'Connection')),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                _switch(tr('فقط پروکسی (بدون VPN)', 'Proxy only (no VPN)'),
                    tr('SOCKS روی 10808 و HTTP روی 10809، بدون رمز و قابل استفاده برای اپ‌های دیگر', 'SOCKS 10808 / HTTP 10809 without a password, usable by other apps'), s.proxyOnly, (v) {
                  s.proxyOnly = v;
                  app.saveSettings();
                }),
                _switch(tr('اتصال خودکار به سریع‌ترین', 'Auto-pick fastest'),
                    tr('هنگام اتصال، کانفیگ با کمترین تأخیر انتخاب می‌شود', 'Connect to the config with the lowest latency'), s.autoBest, (v) {
                  s.autoBest = v;
                  app.saveSettings();
                }),
                _switch('Sniffing', tr('تشخیص دامنه از ترافیک (پیشنهادی)', 'Detect domains from traffic (recommended)'), s.sniffing, (v) {
                  s.sniffing = v;
                  app.saveSettings();
                }),
              ]),
            ),
            const SizedBox(height: 10),
            _field(context, 'DNS', s.dns, (v) => s.dns = v, hint: '1.1.1.1,8.8.8.8'),
            _field(context, tr('آدرس تست تأخیر', 'Latency test URL'), s.testUrl, (v) => s.testUrl = v),
            _field(context, tr('اپ‌هایی که از VPN عبور نکنند (Package name)', 'Apps that bypass the VPN (package names)'), s.blockedApps,
                (v) => s.blockedApps = v,
                hint: 'com.example.app, ir.bank.app', lines: 3),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tr('تعداد تست هم‌زمان', 'Parallel tests')}: ${num2(s.testConcurrency)}',
                    style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
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
                Text(tr('عدد بالاتر = سریع‌تر، ولی مصرف رم بیشتر', 'Higher = faster, but uses more memory'),
                    style: TextStyle(color: p.sub, fontSize: 12)),
              ]),
            ),
            SectionTitle(tr('کانفیگ رایگان', 'Free configs')),
            _nav(context, Icons.key_rounded, '${tr('مدیریت توکن کلودفلر', 'Cloudflare tokens')} (${num2(app.accounts.length)})', const TokensPage()),
            const SizedBox(height: 10),
            _field(context, tr('آی‌پی‌های تمیز کلودفلر (اختیاری)', 'Clean Cloudflare IPs (optional)'), s.cleanIps, (v) => s.cleanIps = v,
                hint: tr('هر آی‌پی در یک خط یا با کاما', 'One per line or comma separated'), lines: 3),
            _field(
              context,
              tr('منابع کانفیگ عمومی (خالی = پیش‌فرض)', 'Public config sources (empty = default)'),
              s.freeSources,
              (v) => s.freeSources = v,
              hint: defaultFreeSources.first,
              lines: 4,
            ),
            SectionTitle(tr('ابزارها', 'Tools')),
            _nav(context, Icons.dns_rounded, tr('سازنده DNS Tunnel (XDNS)', 'DNS tunnel builder (XDNS)'), const XdnsPage()),
            const SizedBox(height: 10),
            _nav(context, Icons.receipt_long_rounded, tr('لاگ‌ها (عیب‌یابی)', 'Logs (troubleshooting)'), const LogsPage()),
            SectionTitle(tr('درباره', 'About')),
            Panel(
              child: Row(children: [
                Image.asset('assets/logo.png', width: 56, height: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Aida VPN 1.2.0', style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Xray ${app.vpn.coreVersion.isEmpty ? '—' : app.vpn.coreVersion}', style: TextStyle(color: p.sub)),
                    const SizedBox(height: 4),
                    Text(
                      'VLESS · VMess · Trojan · Shadowsocks · Hysteria2 · WireGuard/WARP · XDNS · Xray JSON',
                      style: TextStyle(color: p.sub, fontSize: 11.5, height: 1.6),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _nav(BuildContext context, IconData icon, String title, Widget page) => Panel(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Row(children: [
          Icon(icon, color: pal.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(color: pal.text, fontWeight: FontWeight.w700))),
          Icon(forwardChevron, color: pal.sub),
        ]),
      );

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
                  textAlign: ltrValueAlign,
                  style: TextStyle(color: pal.sub, fontSize: 12)),
            ]),
          ),
          Icon(Icons.edit_rounded, size: 18, color: pal.sub),
        ]),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  const _LangCard({required this.code, required this.label, required this.selected});
  final String code;
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Panel(
      highlight: selected,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      onTap: () {
        app.settings.lang = code;
        app.saveSettings();
      },
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? p.primary : p.sub, size: 20),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
      ]),
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
          Text(gold ? tr('مشکی طلایی', 'Black & Gold') : tr('سفید سرمه‌ای', 'White & Navy'),
              style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
