import { createServer } from 'node:http';
import { createServer as createSecureServer } from 'node:https';
import { readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import assert from 'node:assert/strict';

const [program, mode] = process.argv.slice(2);
assert.ok(program, 'provide the native policy network executable');
const secure = mode === '--https';
const upgrade = mode === '--upgrade' || secure;
const seed = randomBytes(16).toString('hex');
const responseCookie = `pudu_policy_response_${seed}`;
const observed = { control: 0, protected: 0, blocked: 0, upgrade: 0, tls: 0, cookieLeaks: 0, bodyChanges: 0, report: null };
let secureServer, trapServer;
const server = createServer(async (request, response) => {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  const body = Buffer.concat(chunks).toString();
  response.setHeader('Cache-Control', 'no-store');
  if (request.url === '/policy-page') {
    response.setHeader('Set-Cookie', `pudu_policy_seed=${seed}; Path=/; SameSite=Lax`);
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    response.end(`<html><body><script>
      (async()=>{
        let report={};
        try {
          const control=await (await fetch('/cookie-control')).json();
          if(!control.cookie.includes('pudu_policy_seed='+${JSON.stringify(seed)}))throw Error('seed missing on control');
          const protectedRequest=await (await fetch('/cookie-protected',{method:'POST',body:'protected-body'})).json();
          if(protectedRequest.cookie!=='')throw Error('automatic cookie reached protected endpoint');
          if(protectedRequest.body!=='protected-body')throw Error('protected body changed');
          const after=await (await fetch('/cookie-control')).json();
          if(after.cookie.includes(${JSON.stringify(responseCookie + '=')}))throw Error('protected response stored a cookie');
          const blocked=await fetch('/blocked-endpoint').then(r=>r.status===403,()=>true);
          if(!blocked)throw Error('blocked request succeeded');
          if(${secure}){
            const upgraded=await (await fetch('http://127.0.0.1/upgrade-endpoint?probe='+${JSON.stringify(seed)},{method:'POST',body:'upgrade-body:'+${JSON.stringify(seed)}})).json();
            if(upgraded.method!=='POST'||upgraded.body!=='upgrade-body:'+${JSON.stringify(seed)}||upgraded.url!=='/upgrade-endpoint?probe='+${JSON.stringify(seed)})throw Error('upgraded POST changed');
          }else if(${upgrade})await fetch('/upgrade-endpoint',{method:'POST',body:'upgrade-body'}).catch(()=>{});
          report={passed:true};
        }catch(error){report={passed:false,error:String(error)}}
        await fetch('/report',{method:'POST',body:JSON.stringify(report)});
        document.title='policy-network:'+(report.passed?'ok':'failed');
      })();
    </script></body></html>`);
  } else if (request.url === '/cookie-control' || request.url === '/cookie-protected') {
    const key = request.url === '/cookie-control' ? 'control' : 'protected';
    observed[key]++;
    observed[key + 'Cookie'] = request.headers.cookie || '';
    observed[key + 'Body'] = body;
    if (key === 'protected') {
      response.setHeader('Set-Cookie', `${responseCookie}=${seed}; Path=/; SameSite=Lax`);
      if (request.headers.cookie) observed.cookieLeaks++;
      if (body !== 'protected-body') observed.bodyChanges++;
    }
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify({ cookie: request.headers.cookie || '', body }));
  } else if (request.url === '/blocked-endpoint' || request.url === '/upgrade-endpoint') {
    observed[request.url === '/blocked-endpoint' ? 'blocked' : 'upgrade']++;
    response.end('policy leaked');
  } else if (request.url === '/report') {
    try { observed.report = JSON.parse(body); } catch { observed.report = { passed: false, error: 'invalid report' }; }
    response.end('received');
  } else { response.statusCode = 404; response.end(); }
});
server.on('clientError', (error, socket) => {
  if (error.rawPacket?.[0] === 0x16) observed.tls++;
  socket.destroy();
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let child;
try {
  if (secure) {
    trapServer = createServer((request, response) => { observed.upgrade++; response.end('insecure delivery'); });
    await new Promise((resolve, reject) => { trapServer.once('error', reject); trapServer.listen(80, '127.0.0.1', resolve); });
    secureServer = createSecureServer({
      key: readFileSync(process.env.PUDU_POLICY_TLS_KEY),
      cert: readFileSync(process.env.PUDU_POLICY_TLS_CERT),
    }, async (request, response) => {
      response.setHeader('Access-Control-Allow-Origin', '*');
      const chunks = [];
      for await (const chunk of request) chunks.push(chunk);
      const body = Buffer.concat(chunks).toString();
      observed.secure = (observed.secure || 0) + 1;
      observed.secureMethod = request.method;
      observed.secureBody = body;
      observed.secureUrl = request.url;
      response.setHeader('Content-Type', 'application/json');
      response.end(JSON.stringify({ method: request.method, body, url: request.url }));
    });
    await new Promise((resolve, reject) => { secureServer.once('error', reject); secureServer.listen(443, '127.0.0.1', resolve); });
  }
  const origin = `http://127.0.0.1:${server.address().port}`;
  child = spawn(program, [origin, ...(upgrade ? ['upgrade'] : [])], { stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  child.stdout.on('data', data => { output += data; });
  child.stderr.on('data', data => { output += data; });
  const timeout = setTimeout(() => child.kill(), 40000);
  let status;
  try {
    status = await new Promise((resolve, reject) => { child.once('error', reject); child.once('close', resolve); });
  } finally { clearTimeout(timeout); }
  process.stdout.write(output);
  assert.equal(status, 0, JSON.stringify(observed));
  assert.equal(observed.report?.passed, true, JSON.stringify(observed));
  assert.ok(observed.control > 0 && observed.protected > 0);
  assert.ok(observed.controlCookie.includes(`pudu_policy_seed=${seed}`));
  assert.ok(!observed.controlCookie.includes(responseCookie + '='), 'protected response cookie was stored');
  assert.equal(observed.protectedCookie, '', 'protected request leaked cookies');
  assert.equal(observed.protectedBody, 'protected-body');
  assert.equal(observed.cookieLeaks, 0);
  assert.equal(observed.bodyChanges, 0);
  assert.equal(observed.blocked, 0, 'blocked request reached HTTP server');
  assert.equal(observed.upgrade, 0, 'upgraded request reached original HTTP endpoint');
  if (secure) {
    assert.ok(observed.secure > 0, 'upgraded request never reached HTTPS');
    assert.equal(observed.secureMethod, 'POST');
    assert.equal(observed.secureBody, `upgrade-body:${seed}`);
    assert.equal(observed.secureUrl, `/upgrade-endpoint?probe=${seed}`);
  } else if (upgrade) assert.ok(observed.tls > 0, 'upgrade did not attempt TLS');
  process.stdout.write(`policy-network-server=1 upgrade-transport=${upgrade ? 1 : 0} upgrade-delivery=${secure ? 1 : 0}\n`);
} finally {
  if (child && child.exitCode === null && child.signalCode === null) child.kill();
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
  for (const listener of [secureServer, trapServer]) if (listener) {
    listener.closeAllConnections();
    await new Promise(resolve => listener.close(resolve));
  }
}
