// Diagnoses the cloud-AI setup using YOUR token (from .replicate-token or the
// REPLICATE_API_TOKEN env var). Prints a report to paste back for a fix.
const fs = require('fs');
const path = require('path');

function token() {
  if (process.env.REPLICATE_API_TOKEN) return process.env.REPLICATE_API_TOKEN.trim();
  try {
    return fs.readFileSync(path.join(__dirname, '..', '.replicate-token'), 'utf8').trim();
  } catch (_) {
    return null;
  }
}

async function main() {
  const t = token();
  console.log('=== TJ Photo Editor — AI diagnosis ===');
  if (!t) {
    console.log('TOKEN: NOT FOUND (no .replicate-token file and no REPLICATE_API_TOKEN env).');
    console.log('=> Set your token first (paste it in the app, or in .replicate-token).');
    return;
  }
  console.log('TOKEN: found, length ' + t.length + ', starts "' + t.slice(0, 3) + '"');
  const auth = { Authorization: 'Bearer ' + t };

  // 1) account / billing
  try {
    const r = await fetch('https://api.replicate.com/v1/account', { headers: auth });
    console.log('ACCOUNT: HTTP ' + r.status + (r.ok ? ' OK' : ' (' + (await r.text()).slice(0, 200) + ')'));
  } catch (e) {
    console.log('ACCOUNT: request failed ' + e);
  }

  // 2) model availability
  const models = [
    'cjwbw/rembg',
    'black-forest-labs/flux-kontext-pro',
    '851-labs/background-remover',
    'men1scus/birefnet',
  ];
  for (const m of models) {
    try {
      const r = await fetch('https://api.replicate.com/v1/models/' + m, { headers: auth });
      if (r.ok) {
        const j = await r.json();
        console.log('MODEL ' + m + ': OK, latest_version=' + (j.latest_version ? j.latest_version.id.slice(0, 10) : 'NONE'));
      } else {
        console.log('MODEL ' + m + ': HTTP ' + r.status);
      }
    } catch (e) {
      console.log('MODEL ' + m + ': request failed ' + e);
    }
  }
  console.log('=== end ===');
}
main();
