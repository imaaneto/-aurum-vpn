import 'package:flutter/material.dart';

import '../core/link_parser.dart';
import '../i18n.dart';
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
      toast(context, tr('UUID و دامنه تونل را درست وارد کنید', 'Enter a valid UUID and tunnel domain'), error: true);
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
            tr(
              'XDNS تونل DNS داخلی هسته Xray است (نسل جدید DNSTT و Slipstream) که ترافیک را داخل کوئری‌های DNS '
                  'از طریق ریزالورهای عمومی عبور می‌دهد و در قطعی‌های شدید هم کار می‌کند.\n'
                  'نیاز به سرور Xray با ورودی VLESS + mKCP + finalmask نوع xdns و رکوردهای NS برای ساب‌دامنه تونل دارد. '
                  'برای هر ریزالور انتخاب‌شده یک کانفیگ ساخته می‌شود تا با تست، سریع‌ترین را انتخاب کنید.',
              'XDNS is the Xray core\'s built-in DNS tunnel (the successor of DNSTT and Slipstream). It carries traffic '
                  'inside DNS queries through public resolvers and keeps working during heavy shutdowns.\n'
                  'It needs an Xray server with a VLESS + mKCP inbound using the xdns finalmask, and NS records for the tunnel subdomain. '
                  'One config is created per selected resolver so you can test and pick the fastest.',
            ),
            style: TextStyle(color: p.sub, height: 1.8, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        TextField(controller: _name, style: TextStyle(color: p.text), decoration: luxInput(tr('نام کانفیگ', 'Config name'))),
        const SizedBox(height: 12),
        TextField(
          controller: _uuid,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: p.text),
          decoration: luxInput(tr('UUID کاربر VLESS', 'VLESS user UUID')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _domain,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: p.text),
          decoration: luxInput(tr('دامنه تونل', 'Tunnel domain'), hint: 't.example.com'),
        ),
        SectionTitle(tr('ریزالورهای DNS', 'DNS resolvers')),
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
            label: Text(tr('ریزالور دلخواه', 'Custom resolver')),
            backgroundColor: p.surface2,
            labelStyle: TextStyle(color: p.text),
            onPressed: () async {
              final v = await askText(context, title: tr('آی‌پی ریزالور', 'Resolver IP'), label: 'IP', hint: '8.8.4.4');
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
        LuxButton(label: tr('ساخت و افزودن کانفیگ‌ها', 'Build and add configs'), icon: Icons.dns_rounded, onTap: _picked.isEmpty ? null : _create),
      ]),
    );
  }
}
