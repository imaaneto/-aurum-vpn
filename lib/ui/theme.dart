import 'package:flutter/material.dart';

import '../i18n.dart';
import '../store.dart';

/// Two luxury palettes: black & gold, white & navy.
class Pal {
  const Pal({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.text,
    required this.sub,
    required this.gradient,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color text;
  final Color sub;
  final List<Color> gradient;

  static const success = Color(0xFF3FBF7F);
  static const warning = Color(0xFFE8A33D);
  static const danger = Color(0xFFE5484D);

  static const gold = Pal(
    dark: true,
    bg: Color(0xFF09090B),
    surface: Color(0xFF141417),
    surface2: Color(0xFF1C1B20),
    border: Color(0xFF2E2919),
    primary: Color(0xFFD4AF37),
    onPrimary: Color(0xFF14110A),
    accent: Color(0xFFF3D98B),
    text: Color(0xFFF6F0E1),
    sub: Color(0xFFA19B8C),
    gradient: [Color(0xFFF6E3A1), Color(0xFFD4AF37), Color(0xFF8E6E17)],
  );

  static const navy = Pal(
    dark: false,
    bg: Color(0xFFF5F7FC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFECF0F9),
    border: Color(0xFFD9DFEE),
    primary: Color(0xFF13245C),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF2E4FA8),
    text: Color(0xFF0F1B45),
    sub: Color(0xFF5F6A8A),
    gradient: [Color(0xFF3D5FC2), Color(0xFF1B3275), Color(0xFF0B1638)],
  );

  static Pal get current => app.settings.darkGold ? gold : navy;
}

Pal get pal => Pal.current;

ThemeData buildTheme(Pal p) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: p.dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.accent,
    surface: p.surface,
    onSurface: p.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    fontFamily: 'Vazirmatn',
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    dividerColor: p.border,
    splashFactory: InkRipple.splashFactory,
  );
}

String fmtBytes(int b) {
  if (b <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

String fmtSpeed(int bps) => '${fmtBytes(bps)}/s';

Color delayColor(int? d) {
  if (d == null) return pal.sub;
  if (d < 0) return Pal.danger;
  if (d < 600) return Pal.success;
  if (d < 1500) return Pal.warning;
  return Pal.danger;
}

String timeAgo(int ms) {
  if (ms == 0) return tr('هرگز', 'never');
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return tr('همین الان', 'just now');
  if (d.inHours < 1) return tr('${num2(d.inMinutes)} دقیقه پیش', '${d.inMinutes} min ago');
  if (d.inDays < 1) return tr('${num2(d.inHours)} ساعت پیش', '${d.inHours} h ago');
  return tr('${num2(d.inDays)} روز پیش', '${d.inDays} days ago');
}

/// Chevron pointing "forward" for the current layout direction.
IconData get forwardChevron => isFa ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;
