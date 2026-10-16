import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/link_parser.dart';
import 'i18n.dart';
import 'store.dart';
import 'ui/configs_page.dart';
import 'ui/free_page.dart';
import 'ui/home_page.dart';
import 'ui/nav.dart';
import 'ui/settings_page.dart';
import 'ui/subs_page.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const AidaApp());
}

class AidaApp extends StatelessWidget {
  const AidaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = pal;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: p.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: p.surface,
          systemNavigationBarIconBrightness: p.dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'Aida VPN',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(p),
          locale: Locale(appLang),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Shell(key: ValueKey('${app.settings.darkGold}-$appLang')),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  String _lastClip = '';

  static const _pages = [HomePage(), ConfigsPage(), FreePage(), SubsPage(), SettingsPage()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabIndex.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabIndex.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 400), _checkClipboard);
    }
  }

  /// Offers to import share links found in the clipboard.
  Future<void> _checkClipboard() async {
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
      if (text.isEmpty || text == _lastClip) return;
      _lastClip = text;
      final links = extractLinks(text);
      final known = app.configs.map((c) => c.dedupeKey).toSet();
      final fresh = links.where((l) {
        final c = configFromLink(l, 'x');
        return c != null && !known.contains(c.dedupeKey);
      }).length;
      if (fresh == 0 || !mounted) return;
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(
        backgroundColor: pal.surface2,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: pal.primary)),
        content: Text(tr('${num2(fresh)} کانفیگ جدید در کلیپ‌بورد پیدا شد', '$fresh new configs found in clipboard'), style: TextStyle(color: pal.text, fontFamily: 'Vazirmatn')),
        action: SnackBarAction(
          label: tr('وارد کن', 'Import'),
          textColor: pal.primary,
          onPressed: () async {
            final r = await app.importText(text);
            if (mounted) toast(context, r.summary);
          },
        ),
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Scaffold(
        backgroundColor: p.bg,
        body: IndexedStack(index: tabIndex.value, children: _pages),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: p.surface,
            indicatorColor: p.primary.withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.all(TextStyle(color: p.text, fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'Vazirmatn')),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(color: states.contains(WidgetState.selected) ? p.primary : p.sub),
            ),
          ),
          child: NavigationBar(
            selectedIndex: tabIndex.value,
            onDestinationSelected: (i) => tabIndex.value = i,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.power_settings_new_rounded), label: tr('خانه', 'Home')),
              NavigationDestination(icon: const Icon(Icons.layers_rounded), label: tr('کانفیگ‌ها', 'Configs')),
              NavigationDestination(icon: const Icon(Icons.card_giftcard_rounded), label: tr('رایگان', 'Free')),
              NavigationDestination(icon: const Icon(Icons.rss_feed_rounded), label: tr('ساب‌ها', 'Subs')),
              NavigationDestination(icon: const Icon(Icons.tune_rounded), label: tr('تنظیمات', 'Settings')),
            ],
          ),
        ),
    );
  }
}
