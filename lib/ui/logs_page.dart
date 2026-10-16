import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Core / app logs for troubleshooting (copyable).
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<String> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final l = await app.vpn.logs();
    if (!mounted) return;
    setState(() {
      _lines = l.reversed.take(400).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        title: Text(tr('لاگ‌ها', 'Logs'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: Icon(Icons.refresh_rounded, color: p.text), onPressed: _load),
          IconButton(
            icon: Icon(Icons.copy_rounded, color: p.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _lines.join('\n')));
              toast(context, tr('کپی شد', 'Copied'));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Pal.danger),
            onPressed: () async {
              await app.vpn.clearLogs();
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: p.primary))
          : _lines.isEmpty
              ? EmptyState(icon: Icons.receipt_long_rounded, title: tr('لاگی وجود ندارد', 'No logs'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _lines.length,
                  itemBuilder: (_, i) => Directionality(
                    textDirection: TextDirection.ltr,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(_lines[i], style: TextStyle(color: p.sub, fontSize: 11, fontFamily: 'monospace')),
                    ),
                  ),
                ),
    );
  }
}
