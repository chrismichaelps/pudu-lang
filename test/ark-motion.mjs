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
const module = join(library, 'Ark/Physics/Motion.pudu');
const fixture = join(root, 'test-fixtures/ark/UsesArkMotion.pudu');
const env = {...process.env, PUDU_LIB: library};
const run = (...args) => execFileSync(binary, args, {cwd: root, env, encoding: 'utf8', timeout: 120000});
assert.equal(run('run', fixture), 'ark motion: ok\n');
run('fmt', '--check', module, fixture, join(root, 'bench/MotionBench.pudu'));
run('lint', module, fixture, join(root, 'bench/MotionBench.pudu'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-motion-'));
try {
  const refused = join(scratch, 'WrongBudget.pudu');
  writeFileSync(refused, 'module WrongBudget\nimport Ark.Math as V\nimport Ark.Physics.Motion as Motion\nexport fn main() -> Int {\n  let result = Motion.move(V.vec3(0.0, 0.0, 0.0), V.vec3(0.0, 0.0, 0.0), "many", |p, d| -> Result[Option[Motion.Contact], Str] { Ok(None) })\n  0\n}\n');
  const checked = spawnSync(binary, ['check', refused], {cwd: root, env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WrongBudget\.pudu:5:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const paths = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  assert(paths.some(path => path.endsWith('/lib/Ark/Physics/Motion.pudu')));
  if (process.argv[3]) {
    const overlay = join(scratch, 'lib');
    mkdirSync(join(overlay, 'Ark/Physics'), {recursive: true});
    mkdirSync(join(overlay, 'Ark/Math'), {recursive: true});
    cpSync(join(library, 'Std'), join(overlay, 'Std'), {recursive: true});
    for (const path of ['Ark/Math.pudu', 'Ark/Physics/Motion.pudu']) cpSync(join(library, path), join(overlay, path));
    for (const path of ['Ark/Math/Distance.pudu', 'Ark/Physics/Cast.pudu']) cpSync(join(resolve(process.argv[3]), path), join(overlay, path));
    const adapter = join(scratch, 'BoxMotion.pudu');
    writeFileSync(adapter, `module BoxMotion
import Std.Math.Float as Float
import Ark.Math as V
import Ark.Physics.Cast as Cast
import Ark.Physics.Motion as Motion
fn query(p: V.Vec3, d: V.Vec3, second: Bool) -> Result[Option[Motion.Contact], Cast.Error] {
  var earliest: Option[Motion.Contact] = None
  let boxes = if second { [(V.vec3(0.0, -10.0, -10.0), V.vec3(1.0, 10.0, 10.0)), (V.vec3(-10.0, 0.0, -10.0), V.vec3(10.0, 1.0, 10.0))] } else { [(V.vec3(0.0, -10.0, -10.0), V.vec3(1.0, 10.0, 10.0))] }
  for (minimum, maximum) in boxes {
    let request = Cast.CapsuleBox{start: p, end: V.add(p, V.vec3(0.0, 0.0, 1.0)), radius: 0.5, displacement: d, minimum, maximum, tolerance: 1e-8, maxIterations: 64}
    if let Some(hit) = Cast.capsuleBox(&request)? {
      let contact = Motion.Contact{fraction: hit.fraction, normal: hit.normal}
      if match earliest { case None => true case Some(old) => hit.fraction < old.fraction } { earliest = Some(contact) }
    }
  }
  Ok(earliest)
}
export fn main() -> Int {
  let Ok(slide) = Motion.move(V.vec3(-2.0, -2.0, 0.0), V.vec3(4.0, 3.0, 0.0), 8, |p, d| query(p, d, false)) else { panic("face query") }
  if slide.exhausted || Float.abs(slide.position.x + 0.5) > 1e-7 || Float.abs(slide.position.y - 1.0) > 1e-7 { panic("face slide") }
  let Ok(edge) = Motion.move(V.vec3(-2.0, 10.3, 0.0), V.vec3(4.0, 0.0, 0.0), 8, |p, d| query(p, d, false)) else { panic("edge query") }
  if edge.exhausted || Float.abs(edge.position.x - 0.464) > 1e-6 || Float.abs(edge.position.y - 11.452) > 1e-6 { panic("rounded edge slide") }
  let Ok(corner) = Motion.move(V.vec3(-2.0, -2.0, 0.0), V.vec3(4.0, 4.0, 3.0), 8, |p, d| query(p, d, true)) else { panic("corner query") }
  if corner.exhausted || Float.abs(corner.position.x + 0.5) > 1e-7 || Float.abs(corner.position.y + 0.5) > 1e-7 || Float.abs(corner.position.z - 3.0) > 1e-7 { panic("corner slide") }
  let Ok(clear) = Motion.move(V.vec3(-2.0, 20.0, 0.0), V.vec3(4.0, 0.0, 0.0), 8, |p, d| query(p, d, false)) else { panic("clear query") }
  if clear.position.x != 2.0 || clear.contacts != 0 { panic("finite obstacle") }
  let failed = Motion.move(V.vec3(0.5, 0.0, 0.0), V.vec3(1.0, 0.0, 0.0), 8, |p, d| query(p, d, false))
  if !(match failed { case Err(Motion.QueryFailed(Cast.InitialOverlap)) => true case _ => false }) { panic("overlap payload") }
  print("box motion: ok")
  0
}
`);
    assert.equal(execFileSync(binary, ['run', adapter], {env: {...env, PUDU_LIB: overlay}, encoding: 'utf8', timeout: 120000}), 'box motion: ok\n');
  }
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Ark swept movement, typed query failures and shipping passed');
