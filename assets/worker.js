// Aurum VPN - minimal VLESS over WebSocket node for Cloudflare Workers.
// Deployed automatically by the app. __UUID__ and __PROXYIP__ are replaced.
import { connect } from 'cloudflare:sockets';

const UUID = '__UUID__';
const PROXYIP = '__PROXYIP__';
const ID_HEX = UUID.replace(/-/g, '').toLowerCase();

export default {
  async fetch(request) {
    const upgrade = request.headers.get('Upgrade') || '';
    if (upgrade.toLowerCase() !== 'websocket') {
      return new Response('Aurum node is running', {
        status: 200,
        headers: { 'content-type': 'text/plain;charset=utf-8' },
      });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    handleSession(server, request.headers.get('sec-websocket-protocol') || '');
    return new Response(null, { status: 101, webSocket: client });
  },
};

function safeClose(ws) {
  try {
    if (ws.readyState === 1 || ws.readyState === 2) ws.close();
  } catch (e) {}
}

function decodeEarlyData(str) {
  if (!str) return null;
  try {
    const b64 = str.replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out.buffer;
  } catch (e) {
    return null;
  }
}

function parseHeader(buf) {
  if (buf.byteLength < 24) return { err: 'short header' };
  const v = new Uint8Array(buf);
  const ver = v[0];
  let id = '';
  for (let i = 1; i < 17; i++) id += v[i].toString(16).padStart(2, '0');
  if (id !== ID_HEX) return { err: 'auth failed' };
  const optLen = v[17];
  let i = 18 + optLen;
  const cmd = v[i++];
  const port = (v[i] << 8) | v[i + 1];
  i += 2;
  const atype = v[i++];
  let addr = '';
  if (atype === 1) {
    addr = Array.from(v.slice(i, i + 4)).join('.');
    i += 4;
  } else if (atype === 2) {
    const len = v[i++];
    addr = new TextDecoder().decode(v.slice(i, i + len));
    i += len;
  } else if (atype === 3) {
    const parts = [];
    for (let k = 0; k < 8; k++) parts.push(((v[i + 2 * k] << 8) | v[i + 2 * k + 1]).toString(16));
    addr = '[' + parts.join(':') + ']';
    i += 16;
  } else {
    return { err: 'bad address type' };
  }
  if (!addr) return { err: 'empty address' };
  return { ver, udp: cmd === 2, port, addr, dataIndex: i };
}

async function handleSession(ws, earlyHeader) {
  let remote = null;
  let dnsWriter = null;

  const inbound = new ReadableStream({
    start(ctrl) {
      ws.addEventListener('message', (e) => ctrl.enqueue(e.data));
      ws.addEventListener('close', () => {
        try { ctrl.close(); } catch (e) {}
      });
      ws.addEventListener('error', (err) => {
        try { ctrl.error(err); } catch (e) {}
      });
      const early = decodeEarlyData(earlyHeader);
      if (early) ctrl.enqueue(early);
    },
    cancel() {
      safeClose(ws);
    },
  });

  async function writeRemote(chunk) {
    const w = remote.writable.getWriter();
    try {
      await w.write(chunk);
    } finally {
      w.releaseLock();
    }
  }

  async function pipeBack(socket, respHeader) {
    let header = respHeader;
    let got = false;
    await socket.readable
      .pipeTo(
        new WritableStream({
          async write(chunk) {
            got = true;
            if (ws.readyState !== 1) throw new Error('ws closed');
            if (header) {
              const merged = new Uint8Array(header.byteLength + chunk.byteLength);
              merged.set(header, 0);
              merged.set(new Uint8Array(chunk), header.byteLength);
              ws.send(merged);
              header = null;
            } else {
              ws.send(chunk);
            }
          },
        }),
      )
      .catch(() => {});
    return got;
  }

  async function openTcp(host, port, firstData, respHeader) {
    remote = connect({ hostname: host, port });
    if (firstData.byteLength > 0) await writeRemote(firstData);
    // Pipe back in the background so the client can keep sending.
    (async () => {
      const got = await pipeBack(remote, respHeader);
      if (!got && PROXYIP && host !== PROXYIP) {
        remote = connect({ hostname: PROXYIP, port });
        if (firstData.byteLength > 0) await writeRemote(firstData);
        await pipeBack(remote, respHeader);
      }
      safeClose(ws);
    })().catch(() => safeClose(ws));
  }

  function openDns(respHeader) {
    let header = respHeader;
    const ts = new TransformStream({
      transform(chunk, ctrl) {
        const v = new Uint8Array(chunk);
        for (let i = 0; i + 2 <= v.length; ) {
          const len = (v[i] << 8) | v[i + 1];
          ctrl.enqueue(v.slice(i + 2, i + 2 + len));
          i += 2 + len;
        }
      },
    });
    ts.readable
      .pipeTo(
        new WritableStream({
          async write(query) {
            const r = await fetch('https://1.1.1.1/dns-query', {
              method: 'POST',
              headers: { 'content-type': 'application/dns-message' },
              body: query,
            });
            const ans = new Uint8Array(await r.arrayBuffer());
            const framed = new Uint8Array(ans.length + 2);
            framed[0] = ans.length >> 8;
            framed[1] = ans.length & 255;
            framed.set(ans, 2);
            if (ws.readyState !== 1) return;
            if (header) {
              const merged = new Uint8Array(header.length + framed.length);
              merged.set(header, 0);
              merged.set(framed, header.length);
              ws.send(merged);
              header = null;
            } else {
              ws.send(framed);
            }
          },
        }),
      )
      .catch(() => {});
    const w = ts.writable.getWriter();
    return (chunk) => w.write(chunk);
  }

  inbound
    .pipeTo(
      new WritableStream({
        async write(chunk) {
          if (dnsWriter) return dnsWriter(chunk);
          if (remote) return writeRemote(chunk);
          const h = parseHeader(chunk);
          if (h.err) throw new Error(h.err);
          const resp = new Uint8Array([h.ver, 0]);
          const body = chunk.slice(h.dataIndex);
          if (h.udp) {
            if (h.port !== 53) throw new Error('UDP is only allowed for DNS');
            dnsWriter = openDns(resp);
            if (body.byteLength > 0) dnsWriter(body);
            return;
          }
          await openTcp(h.addr, h.port, body, resp);
        },
      }),
    )
    .catch(() => safeClose(ws));
}
