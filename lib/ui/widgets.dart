import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/link_parser.dart';
import '../models.dart';
import '../store.dart';
import 'theme.dart';

void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg, style: TextStyle(color: error ? Colors.white : pal.onPrimary, fontFamily: 'Vazirmatn')),
    backgroundColor: error ? Pal.danger : pal.primary,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    duration: const Duration(seconds: 3),
  ));
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin, this.highlight = false, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlight ? p.primary : p.border, width: highlight ? 1.6 : 1),
        boxShadow: [
          BoxShadow(
            color: (p.dark ? Colors.black : p.primary).withValues(alpha: p.dark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class LuxButton extends StatelessWidget {
  const LuxButton({super.key, required this.label, this.icon, this.onTap, this.busy = false, this.expand = true, this.danger = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final colors = danger ? const [Color(0xFFF07178), Color(0xFFB4232A)] : p.gradient;
    final fg = danger ? Colors.white : p.onPrimary;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        else if (icon != null)
          Icon(icon, color: fg, size: 20),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: colors[1].withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: busy ? null : onTap,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: content),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Material(
      color: p.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: p.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.size = 24});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => LinearGradient(colors: pal.gradient).createShader(r),
      child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(gradient: LinearGradient(colors: pal.gradient), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: pal.text, fontWeight: FontWeight.w800, fontSize: 16))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? pal.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class DelayChip extends StatelessWidget {
  const DelayChip({super.key, this.delay, this.testing = false, this.tcp});
  final int? delay;
  final int? tcp;
  final bool testing;
  @override
  Widget build(BuildContext context) {
    if (testing) {
      return SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: pal.primary));
    }
    final d = delay ?? tcp;
    final label = d == null ? '—' : (d < 0 ? 'خطا' : '$d ms');
    return Badge2(delay == null && tcp != null ? 'TCP $label' : label, color: delayColor(d));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: pal.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: pal.text, fontSize: 17, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: pal.sub, fontSize: 13, height: 1.6)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

InputDecoration luxInput(String label, {String? hint, Widget? suffix}) {
  final p = pal;
  OutlineInputBorder b(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    filled: true,
    fillColor: p.surface2,
    labelStyle: TextStyle(color: p.sub),
    hintStyle: TextStyle(color: p.sub.withValues(alpha: 0.6), fontSize: 12),
    enabledBorder: b(p.border),
    focusedBorder: b(p.primary),
    border: b(p.border),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

Future<String?> askText(BuildContext context, {required String title, String label = '', String initial = '', int maxLines = 1, String? hint, String ok = 'تأیید'}) async {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: pal.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pal.border)),
      title: Text(title, style: TextStyle(color: pal.text, fontWeight: FontWeight.w800, fontSize: 17)),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: maxLines,
          minLines: 1,
          textDirection: maxLines > 1 ? TextDirection.ltr : null,
          style: TextStyle(color: pal.text, fontSize: 13),
          decoration: luxInput(label, hint: hint),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('انصراف', style: TextStyle(color: pal.sub))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text(ok, style: TextStyle(color: pal.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'بله'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: pal.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pal.border)),
      title: Text(title, style: TextStyle(color: pal.text, fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(body, style: TextStyle(color: pal.sub, height: 1.6)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('خیر', style: TextStyle(color: pal.sub))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok, style: const TextStyle(color: Pal.danger, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return r ?? false;
}

void showQrSheet(BuildContext context, String title, String data) {
  showModalBottomSheet(
    context: context,
    backgroundColor: pal.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: pal.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Text(title, maxLines: 2, textAlign: TextAlign.center, style: TextStyle(color: pal.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: pal.primary, width: 2),
            ),
            child: QrImageView(
              data: data,
              size: 250,
              backgroundColor: Colors.white,
              errorStateBuilder: (c, e) => const SizedBox(
                width: 250,
                height: 250,
                child: Center(child: Text('این لینک برای QR خیلی طولانی است', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LuxButton(
            label: 'کپی لینک',
            icon: Icons.copy_rounded,
            onTap: () {
              Clipboard.setData(ClipboardData(text: data));
              Navigator.pop(ctx);
              toast(context, 'کپی شد');
            },
          ),
        ]),
      ),
    ),
  );
}

/// A config row used in lists.
class ConfigTile extends StatelessWidget {
  const ConfigTile({super.key, required this.c, this.showGroup = false});
  final VpnConfig c;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final p = pal;
    final selected = app.selectedId == c.id;
    final active = app.activeId == c.id && app.vpn.connected;
    final tr = transportLabel(c);
    return Panel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      highlight: selected,
      onTap: () => app.select(c.id),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected ? LinearGradient(colors: p.gradient) : null,
            color: selected ? null : p.surface2,
          ),
          child: Icon(
            active ? Icons.shield_rounded : (selected ? Icons.check_rounded : Icons.public_rounded),
            color: selected ? p.onPrimary : p.sub,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, textAlign: TextAlign.right,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Badge2(protocolLabel(c.protocol)),
              if (tr.isNotEmpty) Badge2(tr, color: p.accent),
              if (showGroup) Badge2(app.groupName(c.group), color: p.sub),
            ]),
          ]),
        ),
        DelayChip(delay: c.delay, tcp: c.tcpDelay, testing: app.testingIds.contains(c.id)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: p.sub),
          color: p.surface,
          onSelected: (v) async {
            switch (v) {
              case 'qr':
                showQrSheet(context, c.name, c.link);
                break;
              case 'copy':
                await Clipboard.setData(ClipboardData(text: c.link));
                if (context.mounted) toast(context, 'لینک کپی شد');
                break;
              case 'test':
                app.testConfigs([c]);
                break;
              case 'tcp':
                app.testConfigs([c], real: false);
                break;
              case 'rename':
                final n = await askText(context, title: 'تغییر نام', label: 'نام', initial: c.name);
                if (n != null && n.trim().isNotEmpty) app.renameConfig(c, n.trim());
                break;
              case 'delete':
                app.removeConfigs([c.id]);
                break;
            }
          },
          itemBuilder: (_) => [
            _mi('qr', Icons.qr_code_2_rounded, 'نمایش QR'),
            _mi('copy', Icons.copy_rounded, 'کپی لینک'),
            _mi('test', Icons.speed_rounded, 'تست واقعی'),
            _mi('tcp', Icons.network_ping_rounded, 'پینگ TCP'),
            _mi('rename', Icons.edit_rounded, 'تغییر نام'),
            _mi('delete', Icons.delete_outline_rounded, 'حذف'),
          ],
        ),
      ]),
    );
  }

  PopupMenuItem<String> _mi(String v, IconData i, String t) => PopupMenuItem(
        value: v,
        child: Row(children: [Icon(i, size: 18, color: pal.primary), const SizedBox(width: 10), Text(t, style: TextStyle(color: pal.text))]),
      );
}

class Labeled extends StatelessWidget {
  const Labeled({super.key, required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 18, color: pal.primary),
      const SizedBox(height: 6),
      Text(value, textDirection: TextDirection.ltr, style: TextStyle(color: pal.text, fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: pal.sub, fontSize: 11)),
    ]);
  }
}
