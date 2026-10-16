import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/cloudflare_api.dart';
import '../store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Cloudflare token manager: add/verify tokens, deploy workers, manual workers.
class TokensPage extends StatefulWidget {
  const TokensPage({super.key});
  @override
  State<TokensPage> createState() => _TokensPageState();
}

class _TokensPageState extends State<TokensPage> {
  final Set<String> _busy = {};
  final Set<String> _reveal = {};
  String _step = '';

  Future<void> _setup(CfAccount a) async {
    setState(() {
      _busy.add(a.id);
      _step = '';
    });
    try {
      await CloudflareApi.setup(a, onStep: (s) {
        if (mounted) setState(() => _step = s);
      });
      await app.upsertAccount(a);
      if (mounted) toast(context, 'ورکر آماده است: ${a.workerHost}');
    } catch (e) {
      a.status = 'invalid';
      await app.upsertAccount(a);
      if (mounted) toast(context, 'خطا: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(a.id);
          _step = '';
        });
      }
    }
  }

  Future<void> _addToken() async {
    final label = TextEditingController(text: 'اکانت ${app.accounts.length + 1}');
    final token = TextEditingController();
    final accId = TextEditingController();
    final proxy = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pal.border)),
        title: Text('افزودن توکن کلودفلر', style: TextStyle(color: pal.text, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: label, style: TextStyle(color: pal.text), decoration: luxInput('نام')),
              const SizedBox(height: 10),
              TextField(
                controller: token,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: pal.text, fontSize: 13),
                decoration: luxInput(
                  'API Token',
                  suffix: IconButton(
                    icon: Icon(Icons.content_paste_rounded, color: pal.primary),
                    onPressed: () async {
                      final d = await Clipboard.getData(Clipboard.kTextPlain);
                      token.text = d?.text?.trim() ?? '';
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accId,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: pal.text, fontSize: 13),
                decoration: luxInput('Account ID (اختیاری، خودکار پیدا می‌شود)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: proxy,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: pal.text, fontSize: 13),
                decoration: luxInput('ProxyIP (اختیاری)', hint: 'برای باز کردن سایت‌های پشت کلودفلر'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: TextStyle(color: pal.sub))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ذخیره و ساخت ورکر', style: TextStyle(color: pal.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || token.text.trim().isEmpty) return;
    final a = CfAccount(
      id: newId(),
      label: label.text.trim().isEmpty ? 'اکانت' : label.text.trim(),
      token: token.text.trim(),
      accountId: accId.text.trim(),
      proxyIp: proxy.text.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await app.upsertAccount(a);
    await _setup(a);
  }

  Future<void> _addManual() async {
    final host = await askText(context, title: 'هاست ورکر', label: 'host', hint: 'name.user.workers.dev یا دامنه شما');
    if (host == null || host.trim().isEmpty || !mounted) return;
    final uuid = await askText(context, title: 'UUID ورکر', label: 'UUID');
    if (uuid == null || uuid.trim().isEmpty) return;
    final a = CfAccount(
      id: newId(),
      label: 'ورکر دستی',
      workerHost: host.trim(),
      workerUuid: uuid.trim(),
      status: 'manual',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await app.upsertAccount(a);
  }

  Future<void> _delete(CfAccount a) async {
    final ok = await confirm(context, 'حذف توکن', '«${a.label}» حذف شود؟ ورکر ساخته‌شده هم از اکانت کلودفلر پاک می‌شود.', ok: 'حذف');
    if (!ok) return;
    if (!a.isManual && a.workerName.isNotEmpty && a.accountId.isNotEmpty) {
      try {
        await CloudflareApi(a.token).deleteWorker(a.accountId, a.workerName);
      } catch (_) {}
    }
    await app.removeAccount(a);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = pal;
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            foregroundColor: p.text,
            surfaceTintColor: Colors.transparent,
            title: const Text('مدیریت توکن کلودفلر', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ساخت توکن (یک بار، رایگان):', style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '۱. در dash.cloudflare.com ثبت‌نام کنید.\n'
                  '۲. My Profile ← API Tokens ← Create Token\n'
                  '۳. قالب «Edit Cloudflare Workers» را انتخاب و توکن را بسازید.\n'
                  '۴. توکن را اینجا وارد کنید؛ برنامه خودش ورکر VLESS را می‌سازد و با آی‌پی‌های تمیز کانفیگ می‌دهد.\n'
                  'توکن‌ها رمزنگاری‌شده روی همین گوشی ذخیره می‌شوند.',
                  style: TextStyle(color: p.sub, height: 1.9, fontSize: 13),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: LuxButton(label: 'افزودن توکن', icon: Icons.key_rounded, onTap: _addToken)),
              const SizedBox(width: 10),
              GhostButton(label: 'ورکر دستی', icon: Icons.add_link_rounded, onTap: _addManual),
            ]),
            if (_step.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(_step, style: TextStyle(color: p.sub, fontSize: 12.5))),
              ]),
            ],
            const SectionTitle('توکن‌ها و ورکرها'),
            if (app.accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('هنوز توکنی اضافه نشده', textAlign: TextAlign.center, style: TextStyle(color: p.sub)),
              ),
            for (final a in app.accounts) _card(a),
          ]),
        );
      },
    );
  }

  Widget _card(CfAccount a) {
    final p = pal;
    final busy = _busy.contains(a.id);
    final statusColor = switch (a.status) {
      'active' => Pal.success,
      'manual' => p.accent,
      'invalid' => Pal.danger,
      _ => Pal.warning,
    };
    final statusText = switch (a.status) {
      'active' => 'فعال',
      'manual' => 'دستی',
      'invalid' => 'خطا',
      _ => 'بررسی‌نشده',
    };
    return Panel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.cloud_rounded, color: p.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(a.label, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 15))),
          if (busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)) else Badge2(statusText, color: statusColor),
        ]),
        const SizedBox(height: 10),
        if (!a.isManual)
          _kv('توکن', _reveal.contains(a.id) ? a.token : a.maskedToken,
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(_reveal.contains(a.id) ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: p.sub),
                onPressed: () => setState(() => _reveal.contains(a.id) ? _reveal.remove(a.id) : _reveal.add(a.id)),
              )),
        if (a.accountName.isNotEmpty || a.accountId.isNotEmpty) _kv('اکانت', a.accountName.isNotEmpty ? a.accountName : a.accountId),
        if (a.workerHost.isNotEmpty)
          _kv('ورکر', a.workerHost,
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.copy_rounded, size: 18, color: p.sub),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: a.workerHost));
                  toast(context, 'کپی شد');
                },
              )),
        if (a.proxyIp.isNotEmpty) _kv('ProxyIP', a.proxyIp),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!a.isManual)
            GhostButton(
              label: a.hasWorker ? 'ساخت مجدد ورکر' : 'ساخت ورکر',
              icon: Icons.rocket_launch_rounded,
              onTap: busy ? null : () => _setup(a),
            ),
          GhostButton(
            label: 'ویرایش نام',
            icon: Icons.edit_rounded,
            onTap: () async {
              final v = await askText(context, title: 'نام', label: 'نام', initial: a.label);
              if (v != null && v.trim().isNotEmpty) {
                a.label = v.trim();
                await app.upsertAccount(a);
              }
            },
          ),
          if (!a.isManual)
            GhostButton(
              label: 'ProxyIP',
              icon: Icons.alt_route_rounded,
              onTap: () async {
                final v = await askText(context, title: 'ProxyIP', label: 'IP یا دامنه', initial: a.proxyIp);
                if (v == null) return;
                a.proxyIp = v.trim();
                await app.upsertAccount(a);
                if (a.hasWorker) await _setup(a);
              },
            ),
          GhostButton(label: 'حذف', icon: Icons.delete_outline_rounded, onTap: busy ? null : () => _delete(a)),
        ]),
      ]),
    );
  }

  Widget _kv(String k, String v, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(width: 64, child: Text(k, style: TextStyle(color: pal.sub, fontSize: 12))),
          Expanded(
            child: Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: TextStyle(color: pal.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) trailing,
        ]),
      );
}
