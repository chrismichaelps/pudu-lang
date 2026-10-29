import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {cpSync, mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const library = join(root, 'packages/pudu/v0.1/lib');
const module = join(library, 'Ark/Physics/Ground.pudu');
const fixture = join(root, 'test-fixtures/ark/UsesArkGround.pudu');
const env = {...process.env, PUDU_LIB: library};
const run = (...args) => execFileSync(binary, args, {cwd: root, env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark ground: ok\n');
run('fmt', '--check', module, fixture, join(root, 'bench/GroundBench.pudu'));
run('lint', module, fixture, join(root, 'bench/GroundBench.pudu'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ground-'));
try {
  const refused = join(scratch, 'WrongRadius.pudu');
  writeFileSync(refused, 'module WrongRadius\nimport Ark.Math as V\nimport Ark.Physics.Ground as Ground\nexport fn main() -> Int {\n  let settings = Ground.Settings{up: V.vec3(0.0, 0.0, 1.0), radius: "wide", halfHeight: 2.0, maxDistance: 1.0, minUpDot: 0.8, edgeInset: 0.05, contactTolerance: 1e-7}\n  0\n}\n');
  const checked = spawnSync(binary, ['check', refused], {cwd: root, env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WrongRadius\.pudu:5:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const paths = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  assert(paths.some(path => path.endsWith('/lib/Ark/Physics/Ground.pudu')));
  if (process.argv[3]) {
    const overlay = join(scratch, 'lib');
    mkdirSync(join(overlay, 'Ark/Physics'), {recursive: true});
    mkdirSync(join(overlay, 'Ark/Math'), {recursive: true});
    cpSync(join(library, 'Std'), join(overlay, 'Std'), {recursive: true});
    for (const path of ['Ark/Math.pudu', 'Ark/Physics/Ground.pudu']) cpSync(join(library, path), join(overlay, path));
    for (const path of ['Ark/Math/Distance.pudu', 'Ark/Physics/Cast.pudu']) cpSync(join(resolve(process.argv[3]), path), join(overlay, path));
    const adapter = join(scratch, 'BoxGround.pudu');
    writeFileSync(adapter, `module BoxGround
import Std.Math.Float as Float
import Ark.Math as V
import Ark.Physics.Cast as Cast
import Ark.Physics.Ground as Ground
fn query(p: V.Vec3, d: V.Vec3) -> Result[Option[Ground.Hit], Cast.Error] {
  let request = Cast.CapsuleBox{start: V.add(p, V.vec3(0.0, 0.0, -1.5)), end: V.add(p, V.vec3(0.0, 0.0, 1.5)), radius: 0.5, displacement: d, minimum: V.vec3(-2.0, -2.0, -1.0), maximum: V.vec3(2.0, 2.0, 0.0), tolerance: 1e-8, maxIterations: 64}
  let hit = Cast.capsuleBox(&request)?
  Ok(match hit { case None => None case Some(value) => Some(Ground.Hit{fraction: value.fraction, normal: value.normal, point: value.point}) })
}
export fn main() -> Int {
  let settings = Ground.Settings{up: V.vec3(0.0, 0.0, 1.0), radius: 0.5, halfHeight: 2.0, maxDistance: 1.0, minUpDot: 0.8, edgeInset: 0.05, contactTolerance: 1e-7}
  let body = Ground.State{position: V.vec3(0.0, 0.0, 3.0), velocity: V.vec3(1.0, 0.0, -4.0), mode: Ground.Falling}
  let Ok(value) = Ground.settle(&body, &settings, query) else { panic("floor query") }
  if value.state.mode != Ground.Walking || Float.abs(value.state.position.z - 2.0) > 1e-7 || value.state.velocity.z != 0.0 { panic("floor support") }
  let outside = Ground.State{..body, position: V.vec3(3.0, 0.0, 3.0), mode: Ground.Walking}
  let Ok(lost) = Ground.settle(&outside, &settings, query) else { panic("ledge query") }
  if lost.state.mode != Ground.Falling || lost.support != None { panic("finite support") }
  let rising = Ground.State{..body, velocity: V.vec3(0.0, 0.0, 1.0), mode: Ground.Walking}
  let Ok(jump) = Ground.settle(&rising, &settings, |_p, _d| -> Result[Option[Ground.Hit], Cast.Error] { panic("jump queried") }) else { panic("jump state") }
  if jump.state.mode != Ground.Falling { panic("jump grounded") }
  let inside = Ground.State{..body, position: V.vec3(0.0, 0.0, 1.5)}
  let failed = Ground.settle(&inside, &settings, query)
  if !(match failed { case Err(Ground.QueryFailed(Cast.InitialOverlap)) => true case _ => false }) { panic("overlap error") }
  print("box ground: ok")
  0
}
`);
    assert.equal(execFileSync(binary, ['run', adapter], {env: {...env, PUDU_LIB: overlay}, encoding: 'utf8', timeout: 120000}), 'box ground: ok\n');
  }
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Ark capsule support, state settlement and shipping passed');
