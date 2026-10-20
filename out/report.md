# Pipeline test report

## Sources
- Mahdi0024/ProxyCollector/master/sub/proxies.txt: {'status': 200, 'links': 32, 'parsed': 14}
- Rayan-Config/C-Sub/main/configs/proxy.txt: {'status': 200, 'links': 47, 'parsed': 47}
- NiREvil/vless/main/sub/SSTime: {'status': 200, 'links': 124, 'parsed': 114}
- Kwinshadow/TelegramV2rayCollector/main/sublinks/mix.txt: {'status': 200, 'links': 84, 'parsed': 77}
- barry-far/V2ray-Config/main/Sub1.txt: {'status': 200, 'links': 495, 'parsed': 486}
- 4n0nymou3/multi-proxy-config-fetcher/main/configs/proxy_configs.txt: {'status': 200, 'links': 175, 'parsed': 174}
- youfoundamin/V2rayCollector/main/mixed_iran.txt: {'status': 200, 'links': 591, 'parsed': 501}
- roosterkid/openproxylist/main/V2RAY_RAW.txt: {'status': 200, 'links': 150, 'parsed': 116}
- Kolandone/v2raycollector/main/config.txt: {'status': 200, 'links': 265, 'parsed': 245}
- MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub2.txt: {'status': 200, 'links': 199, 'parsed': 146}
- MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub3.txt: {'status': 200, 'links': 200, 'parsed': 194}
- MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub1.txt: {'status': 200, 'links': 195, 'parsed': 101}
- F0rc3Run/F0rc3Run/main/splitted-by-protocol/vless.txt: {'status': 200, 'links': 218, 'parsed': 185}
- ShatakVPN/ConfigForge-V2Ray/main/configs/vless.txt: {'status': 200, 'links': 231, 'parsed': 154}
- V2RayRoot/V2RayConfig/main/Config/vless.txt: {'status': 200, 'links': 263, 'parsed': 221}
- hans-thomas/v2ray-subscription/master/servers.txt: {'status': 200, 'links': 220, 'parsed': 219}
- barry-far/V2ray-Config/main/Sub3.txt: {'status': 200, 'links': 500, 'parsed': 419}
- arshiacomplus/v2rayExtractor/main/mix/sub.html: {'status': 200, 'links': 332, 'parsed': 253}
- 10ium/ScrapeAndCategorize/main/output_configs/Trojan.txt: {'status': 200, 'links': 932, 'parsed': 909}
- Danialsamadi/v2go/main/AllConfigsSub.txt: {'status': 200, 'links': 430, 'parsed': 400}
- Epodonios/v2ray-configs/main/Sub3.txt: {'status': 200, 'links': 1000, 'parsed': 877}
- Epodonios/v2ray-configs/main/Sub2.txt: {'status': 200, 'links': 1000, 'parsed': 816}
- MhdiTaheri/V2rayCollector/main/sub/mix: {'status': 200, 'links': 1802, 'parsed': 511}
- barry-far/V2ray-Config/main/Sub2.txt: {'status': 200, 'links': 500, 'parsed': 497}
- Epodonios/v2ray-configs/main/Sub1.txt: {'status': 200, 'links': 994, 'parsed': 982}

Unique by protocol: {'vless': 1443, 'vmess': 399, 'ss': 726, 'hysteria2': 113, 'trojan': 542, 'socks': 1}
Build errors: {"vmess: type 'bool' is not a subtype of type 'String?'": 1}

  - vmess: type 'bool' is not a subtype of type 'String?'  <=  vmess://ewogICJ2IjogMiwKICAicHMiOiAiVk1FU1Mt5Yqg5ou/5aSnLU5G6Kej6ZSB5Yqg5ou/5aSn5Zyw5Yy66Z2e6Ieq5Yi25YmnLUNoYXRHUFQtVGlrVG9rLVlvdVR1YmUtNTEuNzkuMTAyLjI1Mzo4MCIs

WARP: {'registered': 2, 'sample_link': 'wireguard://aN8nNIRKPC7%2BsoP64V29wWSe%2BEUhBtY%2FP0P5P1QkS1k%3D@188.114.97.229:928?address=172.16.0.2%2F32%2C2606%3A4700%3A110%3A8cf2%3Afa7f%3A5fb0%3Aa5b8%3Abb6c%2F128&publickey=bmXOC%2BF1FxEMF9dyiK2H5%2F1SUtzH0JuVo51h2wPfgyo%3D&reserved=145,125,27&mtu=1280#WARP'}

## configs
- **pub_hysteria2**: 1/60 ok, 0 config errors
    - 33× Get "https://www.gstatic.com/generate_204": net/http: TLS handshake timeout
    - 26× Get "https://www.gstatic.com/generate_204": io: read/write on closed pipe
- **pub_socks**: 0/1 ok, 0 config errors
    - 1× Get "https://www.gstatic.com/generate_204": net/http: TLS handshake timeout
- **pub_ss**: 9/60 ok, 0 config errors
    - 40× Get "https://www.gstatic.com/generate_204": net/http: TLS handshake timeout
    - 11× Get "https://www.gstatic.com/generate_204": io: read/write on closed pipe
- **pub_trojan**: 7/60 ok, 0 config errors
    - 44× Get "https://www.gstatic.com/generate_204": io: read/write on closed pipe
    - 9× Get "https://www.gstatic.com/generate_204": net/http: TLS handshake timeout
- **pub_vless**: 10/60 ok, 2 config errors
    - 31× Get "https://www.gstatic.com/generate_204": io: read/write on closed pipe
    - 11× Get "https://www.gstatic.com/generate_204": net/http: TLS handshake timeout
    - 6× Get "https://www.gstatic.com/generate_204": EOF
    - 2× config load error: infra/conf/serial: failed to parse json config > infra/conf: failed to build outbound config with tag proxy > infra/conf:
- **pub_vmess**: 8/60 ok, 0 config errors
    - 32× Get "https://www.gstatic.com/generate_204": net/http: TLS handshake timeout
    - 19× Get "https://www.gstatic.com/generate_204": io: read/write on closed pipe
    - 1× Get "https://www.gstatic.com/generate_204": EOF
- **warp**: 9/10 ok, 0 config errors
    - 1× Get "https://www.gstatic.com/generate_204": net/http: TLS handshake timeout
## loadonly
- **workerfrag**: 1/1 ok, 0 config errors
- **xdns**: 1/1 ok, 0 config errors
