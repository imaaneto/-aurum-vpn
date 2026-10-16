import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/link_parser.dart';

class SubFetchResult {
  SubFetchResult(this.links);
  final List<String> links;
  int upload = 0;
  int download = 0;
  int total = 0;
  int expire = 0;
  String? title;
}

Future<SubFetchResult> fetchSubscription(String url) async {
  final r = await http.get(Uri.parse(url.trim()), headers: {
    'User-Agent': 'v2rayNG/1.9.30',
    'Accept': '*/*',
  }).timeout(const Duration(seconds: 25));
  if (r.statusCode != 200) {
    throw Exception('HTTP ${r.statusCode}');
  }
  final body = utf8.decode(r.bodyBytes, allowMalformed: true);
  final res = SubFetchResult(extractLinks(body));

  final info = r.headers['subscription-userinfo'];
  if (info != null) {
    for (final part in info.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length != 2) continue;
      final v = int.tryParse(kv[1].trim().split('.').first) ?? 0;
      switch (kv[0].trim()) {
        case 'upload':
          res.upload = v;
          break;
        case 'download':
          res.download = v;
          break;
        case 'total':
          res.total = v;
          break;
        case 'expire':
          res.expire = v;
          break;
      }
    }
  }
  final title = r.headers['profile-title'];
  if (title != null && title.isNotEmpty) {
    res.title = title.startsWith('base64:') ? (tryBase64(title.substring(7)) ?? title) : title;
  }
  return res;
}
