import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'store.dart';

/// Active UI language: 'fa' or 'en'. Follows the device when not set.
String get appLang {
  final l = app.settings.lang;
  if (l == 'fa' || l == 'en') return l;
  return PlatformDispatcher.instance.locale.languageCode == 'fa' ? 'fa' : 'en';
}

bool get isFa => appLang == 'fa';

/// Picks the Persian or English text for the current language.
String tr(String fa, String en) => isFa ? fa : en;

/// Alignment for left-to-right technical text (hosts, links) inside the
/// current layout direction.
TextAlign get ltrValueAlign => isFa ? TextAlign.right : TextAlign.left;

/// Persian digits for counters when the UI is Persian.
String num2(Object n) {
  final s = '$n';
  if (!isFa) return s;
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return s.replaceAllMapped(RegExp(r'\d'), (m) => fa[int.parse(m[0]!)]);
}
