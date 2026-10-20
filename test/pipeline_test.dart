// End-to-end check of the config pipeline, run in CI (not on the phone):
// fetch public sources -> parse links -> build Xray JSON, plus WARP
// registration. The JSON files are then loaded and connection-tested by
// tool/delaytest (real Xray core).
import 'dart:convert';
import 'dart:io';

import 'package:aida_vpn/core/link_parser.dart';
import 'package:aida_vpn/models.dart';
import 'package:aida_vpn/services/free_engine.dart' show defaultFreeSources;
import 'package:aida_vpn/services/cloudflare_api.dart' show buildWorkerVlessLink;
import 'package:aida_vpn/services/warp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('config pipeline', () async {
    final out = Directory('out/configs')..createSync(recursive: true);
    final settings = AppSettings();
    final summary = <String, dynamic>{};
    final sourceStats = <String, dynamic>{};
    final all = <VpnConfig>[];
    final seen = <String>{};

    await Future.wait(defaultFreeSources.map((u) async {
      try {
        final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 30));
        final links = extractLinks(utf8.decode(r.bodyBytes, allowMalformed: true));
        var parsed = 0;
        for (final l in links) {
          final c = configFromLink(l, Groups.freePublic);
          if (c == null) continue;
          parsed++;
          if (seen.add('${c.host}:${c.port}')) all.add(c);
        }
        sourceStats[u] = {'status': r.statusCode, 'links': links.length, 'parsed': parsed};
      } catch (e) {
        sourceStats[u] = {'error': '$e'};
      }
    }));
    summary['sources'] = sourceStats;

    final byProto = <String, List<VpnConfig>>{};
    for (final c in all) {
      byProto.putIfAbsent(c.protocol, () => []).add(c);
    }
    summary['unique_by_protocol'] = {for (final e in byProto.entries) e.key: e.value.length};

    final buildErrors = <String, int>{};
    final buildErrorSamples = <String>[];
    var written = 0;
    for (final e in byProto.entries) {
      final list = e.value..shuffle();
      var n = 0;
      for (final c in list) {
        if (n >= 60) break;
        try {
          final json = buildXrayJson(c, settings);
          File('${out.path}/pub_${e.key}_$n.json').writeAsStringSync(json);
          n++;
          written++;
        } catch (err) {
          final k = '${e.key}: ${err.toString().split('\n').first}';
          buildErrors[k] = (buildErrors[k] ?? 0) + 1;
          if (buildErrorSamples.length < 15) buildErrorSamples.add('$k  <=  ${c.link.substring(0, c.link.length.clamp(0, 160))}');
        }
      }
    }
    summary['written_public'] = written;
    summary['build_errors'] = buildErrors;
    summary['build_error_samples'] = buildErrorSamples;

    // WARP
    final warp = <String, dynamic>{};
    try {
      final accs = <WarpAccount>[];
      for (var i = 0; i < 2; i++) {
        accs.add(await WarpService.register());
      }
      warp['registered'] = accs.length;
      for (var i = 0; i < 10; i++) {
        final link = WarpService.linkFor(accs[i % accs.length],
            ip: WarpService.randomEndpointIp(), port: WarpService.randomPort(), name: 'WARP');
        final c = configFromLink(link, Groups.freeCf)!;
        File('${out.path}/warp_$i.json').writeAsStringSync(buildXrayJson(c, settings));
        if (i == 0) warp['sample_link'] = link;
      }
    } catch (e) {
      warp['error'] = '$e';
    }
    summary['warp'] = warp;

    // Config-only checks (not expected to connect).
    final xdns = buildXdnsLink(uuid: '11111111-2222-3333-4444-555555555555', domain: 't.example.com', resolver: '8.8.8.8', name: 'x');
    Directory('out/loadonly').createSync(recursive: true);
    final frag = buildWorkerVlessLink(uuid: '11111111-2222-3333-4444-555555555555', host: 'a.b.workers.dev', address: '104.16.1.1', port: 443, name: 'w', fragment: true);
    File('out/loadonly/workerfrag.json').writeAsStringSync(buildXrayJson(configFromLink(frag, Groups.manual)!, settings));
    File('out/loadonly/xdns.json').writeAsStringSync(buildXrayJson(configFromLink(xdns, Groups.manual)!, settings));

    File('out/summary.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(summary));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
