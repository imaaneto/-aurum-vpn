import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import 'import_actions.dart';
import 'theme.dart';
import 'widgets.dart';

class SubsPage extends StatelessWidget {
  const SubsPage({super.key});

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
            title: Text('ساب‌ها (${app.subs.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              if (app.subs.isNotEmpty)
                IconButton(
                  tooltip: 'به‌روزرسانی همه',
                  icon: app.updatingSubs.isNotEmpty
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
                      : Icon(Icons.sync_rounded, color: p.text),
                  onPressed: app.updatingSubs.isNotEmpty ? null : () => app.updateAllSubscriptions(),
                ),
              IconButton(
                tooltip: 'افزودن ساب',
                icon: Icon(Icons.add_circle_rounded, color: p.primary, size: 30),
                onPressed: () => addSubscriptionDialog(context),
              ),
            ],
          ),
          body: app.subs.isEmpty
              ? EmptyState(
                  icon: Icons.rss_feed_rounded,
                  title: 'هنوز سابی اضافه نشده',
                  subtitle: 'لینک اشتراک را وارد کنید؛ کانفیگ‌هایش با نام ساب نمایش داده می‌شود و مصرف و تاریخ انقضا هم نشان داده می‌شود.',
                  action: LuxButton(label: 'افزودن ساب', icon: Icons.add_rounded, expand: false, onTap: () => addSubscriptionDialog(context)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: [for (final s in app.subs) _SubCard(s: s)],
                ),
        );
      },
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.s});
  final Subscription s;

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final count = app.inGroup(s.id).length;
    final healthy = app.inGroup(s.id).where((c) => (c.delay ?? -1) > 0).length;
    final updating = app.updatingSubs.contains(s.id);
    final used = s.upload + s.download;
    final expireDays = s.expire > 0
        ? DateTime.fromMillisecondsSinceEpoch(s.expire * 1000).difference(DateTime.now()).inDays
        : null;
    return Panel(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubDetailPage(sub: s))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: LinearGradient(colors: p.gradient), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.rss_feed_rounded, color: p.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(Uri.tryParse(s.url)?.host ?? s.url,
                  maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: TextStyle(color: p.sub, fontSize: 12)),
            ]),
          ),
          if (updating) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Badge2('$count کانفیگ'),
          if (healthy > 0) Badge2('$healthy سالم', color: Pal.success),
          Badge2('به‌روزرسانی: ${timeAgo(s.updatedAt)}', color: p.sub),
          if (expireDays != null) Badge2(expireDays >= 0 ? '$expireDays روز تا انقضا' : 'منقضی شده', color: expireDays > 3 ? p.accent : Pal.danger),
        ]),
        if (s.total > 0) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (used / s.total).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: used / s.total > 0.9 ? Pal.danger : p.primary,
              backgroundColor: p.surface2,
            ),
          ),
          const SizedBox(height: 6),
          Text('${fmtBytes(used)} از ${fmtBytes(s.total)}', textDirection: TextDirection.ltr, style: TextStyle(color: p.sub, fontSize: 12)),
        ],
        if (s.lastError != null) ...[
          const SizedBox(height: 8),
          Text('خطا: ${s.lastError}', style: const TextStyle(color: Pal.danger, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          GhostButton(
            label: 'به‌روزرسانی',
            icon: Icons.sync_rounded,
            onTap: updating
                ? null
                : () async {
                    final err = await app.updateSubscription(s);
                    if (context.mounted) toast(context, err ?? 'به‌روز شد ✓', error: err != null);
                  },
          ),
          GhostButton(label: 'تست', icon: Icons.speed_rounded, onTap: () => app.testConfigs(app.inGroup(s.id))),
          GhostButton(
            label: 'کپی لینک',
            icon: Icons.copy_rounded,
            onTap: () {
              Clipboard.setData(ClipboardData(text: s.url));
              toast(context, 'لینک ساب کپی شد');
            },
          ),
          GhostButton(label: 'QR', icon: Icons.qr_code_2_rounded, onTap: () => showQrSheet(context, s.name, s.url)),
          GhostButton(label: 'ویرایش', icon: Icons.edit_rounded, onTap: () => _edit(context)),
          GhostButton(
            label: 'حذف',
            icon: Icons.delete_outline_rounded,
            onTap: () async {
              if (await confirm(context, 'حذف ساب', '«${s.name}» و کانفیگ‌هایش حذف شوند؟', ok: 'حذف')) {
                app.deleteSubscription(s);
              }
            },
          ),
        ]),
      ]),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final name = await askText(context, title: 'نام ساب', label: 'نام', initial: s.name);
    if (name == null || !context.mounted) return;
    final url = await askText(context, title: 'لینک ساب', label: 'URL', initial: s.url);
    if (url == null) return;
    await app.editSubscription(s, name, url);
  }
}

class SubDetailPage extends StatelessWidget {
  const SubDetailPage({super.key, required this.sub});
  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.vpn]),
      builder: (context, _) {
        final p = pal;
        final list = app.inGroup(sub.id);
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            foregroundColor: p.text,
            surfaceTintColor: Colors.transparent,
            title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                tooltip: 'تست همه',
                icon: Icon(app.testing ? Icons.stop_circle_outlined : Icons.speed_rounded, color: p.primary),
                onPressed: () => app.testing ? app.cancelTest() : app.testConfigs(list),
              ),
              IconButton(
                tooltip: 'به‌روزرسانی',
                icon: Icon(Icons.sync_rounded, color: p.text),
                onPressed: () => app.updateSubscription(sub),
              ),
            ],
          ),
          body: list.isEmpty
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: app.updatingSubs.contains(sub.id) ? 'در حال دریافت...' : 'کانفیگی در این ساب نیست',
                  subtitle: sub.lastError,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                  itemCount: list.length,
                  itemBuilder: (_, i) => ConfigTile(c: list[i]),
                ),
        );
      },
    );
  }
}
