// Zero-dependency static server for the built Flutter web app (build/web).
// Serves with correct MIME types (incl. .wasm for CanvasKit). Node only.
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'build', 'web');
const port = process.env.PORT || 8080;

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.map': 'application/json',
  '.symbols': 'text/plain',
};

if (!fs.existsSync(path.join(root, 'index.html'))) {
  console.error('build/web not found. Run "flutter build web" first.');
  process.exit(1);
}

// ---- Replicate proxy (so the browser never sees the token, no CORS) ----
// Token comes from REPLICATE_API_TOKEN or a ".replicate-token" file at the
// project root. The app calls same-origin /api/* ; we add the token here.
function replicateToken() {
  if (process.env.REPLICATE_API_TOKEN) return process.env.REPLICATE_API_TOKEN.trim();
  try {
    return fs.readFileSync(path.join(__dirname, '..', '.replicate-token'), 'utf8').trim();
  } catch (_) {
    return null;
  }
}

function readBody(req) {
  return new Promise((resolve) => {
    let b = '';
    req.on('data', (c) => (b += c));
    req.on('end', () => resolve(b));
  });
}

async function handleApi(req, res, urlPath) {
  const token = replicateToken();
  if (urlPath === '/api/config') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ hasToken: !!token }));
  }
  if (urlPath === '/api/replicate' && req.method === 'POST') {
    if (!token) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: 'no-token' }));
    }
    try {
      const { model, input } = JSON.parse(await readBody(req));
      // `Prefer: wait` blocks until the prediction finishes (up to ~60s),
      // so the output is returned directly — no polling needed.
      const r = await fetch(
        `https://api.replicate.com/v1/models/${model}/predictions`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
            Prefer: 'wait',
          },
          body: JSON.stringify({ input }),
        },
      );
      const text = await r.text();
      if (!r.ok) {
        res.writeHead(r.status, { 'Content-Type': 'application/json' });
        return res.end(text);
      }
      const pred = JSON.parse(text);
      // Fetch the result image server-side and hand it back as a data URI, so
      // the browser never makes a cross-origin request for it.
      let image = null;
      const out = pred.output;
      const url = Array.isArray(out) ? out[0] : out;
      if (typeof url === 'string' && url.startsWith('http')) {
        try {
          const imgRes = await fetch(url);
          const buf = Buffer.from(await imgRes.arrayBuffer());
          const ct = imgRes.headers.get('content-type') || 'image/png';
          image = `data:${ct};base64,${buf.toString('base64')}`;
        } catch (_) {}
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ status: pred.status, error: pred.error, image }));
    } catch (e) {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: String(e) }));
    }
  }
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not-found' }));
}

const server = http.createServer((req, res) => {
  let urlPath = decodeURIComponent(req.url.split('?')[0]);
  if (urlPath.startsWith('/api/')) {
    handleApi(req, res, urlPath);
    return;
  }
  if (urlPath === '/') urlPath = '/index.html';
  const file = path.normalize(path.join(root, urlPath));
  if (!file.startsWith(root)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }
  fs.readFile(file, (err, data) => {
    if (err) {
      // Fall back to index.html so deep links / routing still load.
      fs.readFile(path.join(root, 'index.html'), (e2, d2) => {
        if (e2) {
          res.writeHead(404);
          res.end('Not found');
        } else {
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(d2);
        }
      });
      return;
    }
    const ext = path.extname(file).toLowerCase();
    res.writeHead(200, { 'Content-Type': types[ext] || 'application/octet-stream' });
    res.end(data);
  });
});

server.listen(port, () => {
  console.log('TJ Photo Editor running at http://localhost:' + port);
});
