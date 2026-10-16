import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import 'qr_scan_page.dart';
import 'theme.dart';
import 'widgets.dart';
import 'xdns_page.dart';

Future<void> importFromClipboard(BuildContext context) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text ?? '';
  if (text.trim().isEmpty) {
    if (context.mounted) toast(context, 'کلیپ‌بورد خالی است', error: true);
    return;
  }
  final r = await app.importText(text);
  if (context.mounted) toast(context, r.summary, error: r.added == 0 && r.subscriptions == 0);
}

Future<void> importFromQr(BuildContext context) async {
  final v = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrScanPage()));
  if (v == null) return;
  final r = await app.importText(v);
  if (context.mounted) toast(context, r.summary, error: r.added == 0 && r.subscriptions == 0);
}

Future<void> importManual(BuildContext context) async {
  final t = await askText(
    context,
    title: 'وارد کردن دستی',
    label: 'لینک‌ها، متن ساب یا JSON',
    hint: 'vless://...  vmess://...  trojan://...  ss://...  hy2://...  wireguard://...',
    maxLines: 8,
    ok: 'وارد کن',
  );
  if (t == null || t.trim().isEmpty) return;
  final r = await app.importText(t);
  if (context.mounted) toast(context, r.summary, error: r.added == 0 && r.subscriptions == 0);
}

Future<void> addSubscriptionDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final urlCtrl = TextEditingController();
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
  if (clip.startsWith('http')) urlCtrl.text = clip;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: pal.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pal.border)),
      title: Text('افزودن ساب', style: TextStyle(color: pal.text, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: TextStyle(color: pal.text), decoration: luxInput('نام ساب (اختیاری)')),
          const SizedBox(height: 12),
          TextField(
            controller: urlCtrl,
            textDirection: TextDirection.ltr,
            style: TextStyle(color: pal.text, fontSize: 13),
            decoration: luxInput(
              'لینک ساب',
              hint: 'https://...',
              suffix: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'چسباندن',
                  icon: Icon(Icons.content_paste_rounded, color: pal.primary),
                  onPressed: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    urlCtrl.text = d?.text?.trim() ?? '';
                  },
                ),
                IconButton(
                  tooltip: 'اسکن QR',
                  icon: Icon(Icons.qr_code_scanner_rounded, color: pal.primary),
                  onPressed: () async {
                    final v = await Navigator.push<String>(ctx, MaterialPageRoute(builder: (_) => const QrScanPage()));
                    if (v != null) urlCtrl.text = v.trim();
                  },
                ),
              ]),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: TextStyle(color: pal.sub))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('افزودن و دریافت', style: TextStyle(color: pal.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  if (ok != true || urlCtrl.text.trim().isEmpty) return;
  if (!urlCtrl.text.trim().startsWith('http')) {
    if (context.mounted) toast(context, 'لینک ساب باید با http شروع شود', error: true);
    return;
  }
  if (context.mounted) toast(context, 'در حال دریافت ساب...');
  final err = await app.addSubscription(nameCtrl.text, urlCtrl.text);
  if (context.mounted) toast(context, err ?? 'ساب اضافه شد ✓', error: err != null);
}

void showImportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: pal.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) {
      Widget item(IconData i, String t, String s, VoidCallback f) => ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(gradient: LinearGradient(colors: pal.gradient), borderRadius: BorderRadius.circular(12)),
              child: Icon(i, color: pal.onPrimary, size: 22),
            ),
            title: Text(t, style: TextStyle(color: pal.text, fontWeight: FontWeight.w700)),
            subtitle: Text(s, style: TextStyle(color: pal.sub, fontSize: 12)),
            onTap: () {
              Navigator.pop(ctx);
              f();
            },
          );
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: pal.border, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              item(Icons.content_paste_rounded, 'از کلیپ‌بورد', 'لینک، چند لینک، متن base64 یا لینک ساب', () => importFromClipboard(context)),
              item(Icons.qr_code_scanner_rounded, 'اسکن QR', 'با دوربین یا از تصویر گالری', () => importFromQr(context)),
              item(Icons.edit_note_rounded, 'وارد کردن دستی', 'چسباندن متن یا کانفیگ JSON ایکس‌ری', () => importManual(context)),
              item(Icons.rss_feed_rounded, 'افزودن ساب', 'لینک اشتراک با نام دلخواه', () => addSubscriptionDialog(context)),
              item(Icons.dns_rounded, 'ساخت کانفیگ DNS Tunnel', 'XDNS (نسل جدید DNSTT) روی هسته Xray', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const XdnsPage()));
              }),
            ]),
          ),
        ),
      );
    },
  );
}

String groupTitle(String g) => app.groupName(g);
bool isFreeGroup(String g) => g == Groups.freeCf || g == Groups.freePublic;
