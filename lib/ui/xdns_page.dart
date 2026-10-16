import 'package:flutter/material.dart';

import '../core/link_parser.dart';
import '../store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Builder for Xray XDNS (DNS tunnel) configs.
class XdnsPage extends StatefulWidget {
  const XdnsPage({super.key});
  @override
  State<XdnsPage> createState() => _XdnsPageState();
}

class _XdnsPageState extends State<XdnsPage> {
  final _uuid = TextEditingController();
  final _domain = TextEditingController();
  final _name = TextEditingController(text: 'DNS Tunnel');
  final _resolvers = <String>['8.8.8.8', '1.1.1.1', '9.9.9.9', '208.67.222.222'];
  final Set<String> _picked = {'8.8.8.8', '1.1.1.1'};

  Future<void> _create() async {
    final uuid = _uuid.text.trim();
    final domain = _domain.text.trim();
    if (uuid.length < 8 || !domain.contains('.')) {
      toast(context, 'UUID و دامنه تونل را درست وارد کنید', error: true);
      return;
    }
    final links = _picked
        .map((r) => buildXdnsLink(uuid: uuid, domain: domain, resolver: r, name: '${_name.text.trim()} · $r'))
        .join('\n');
    final res = await app.importText(links);
    if (!mounted) return;
    toast(context, res.summary, error: res.added == 0);
    if (res.added > 0) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        title: const Text('DNS Tunnel (XDNS)', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          child: Text(
            'XDNS تونل DNS داخلی هسته Xray است (نسل جدید DNSTT و Slipstream) که ترافیک را داخل کوئری‌های DNS '
            'از طریق ریزالورهای عمومی عبور می‌دهد و در قطعی‌های شدید هم کار می‌کند.\n'
            'نیاز به سرور Xray با ورودی VLESS + mKCP + finalmask نوع xdns و رکوردهای NS برای ساب‌دامنه تونل دارد. '
            'برای هر ریزالور انتخاب‌شده یک کانفیگ ساخته می‌شود تا با تست، سریع‌ترین را انتخاب کنید.',
            style: TextStyle(color: p.sub, height: 1.8, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        TextField(controller: _name, style: TextStyle(color: p.text), decoration: luxInput('نام کانفیگ')),
        const SizedBox(height: 12),
        TextField(
          controller: _uuid,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: p.text),
          decoration: luxInput('UUID کاربر VLESS'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _domain,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: p.text),
          decoration: luxInput('دامنه تونل', hint: 't.example.com'),
        ),
        const SectionTitle('ریزالورهای DNS'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in _resolvers)
            FilterChip(
              label: Text(r, textDirection: TextDirection.ltr),
              selected: _picked.contains(r),
              selectedColor: p.primary.withValues(alpha: 0.25),
              checkmarkColor: p.primary,
              backgroundColor: p.surface2,
              labelStyle: TextStyle(color: p.text),
              onSelected: (v) => setState(() => v ? _picked.add(r) : _picked.remove(r)),
            ),
          ActionChip(
            avatar: Icon(Icons.add, color: p.primary, size: 18),
            label: const Text('ریزالور دلخواه'),
            backgroundColor: p.surface2,
            labelStyle: TextStyle(color: p.text),
            onPressed: () async {
              final v = await askText(context, title: 'آی‌پی ریزالور', label: 'IP', hint: '8.8.4.4');
              if (v != null && v.trim().isNotEmpty) {
                setState(() {
                  _resolvers.add(v.trim());
                  _picked.add(v.trim());
                });
              }
            },
          ),
        ]),
        const SizedBox(height: 24),
        LuxButton(label: 'ساخت و افزودن کانفیگ‌ها', icon: Icons.dns_rounded, onTap: _picked.isEmpty ? null : _create),
      ]),
    );
  }
}
