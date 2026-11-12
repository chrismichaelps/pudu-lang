const pudu = window.__pudu;
const status = document.getElementById('status');

document.getElementById('save').addEventListener('click', async () => {
  try {
    const note = await pudu.invoke('save', {
      title: document.getElementById('title').value,
      body: document.getElementById('body').value,
    });
    status.textContent = `Saved "${note.title}" (${note.words} words)`;
  } catch (problem) {
    status.textContent = `${problem.kind}: ${problem.message}`;
  }
});

// The self-test exercises every IPC path once and reports to the program.
async function selfTest() {
  const failed = [];
  let passed = 0;
  const check = (name, ok) => (ok ? passed++ : failed.push(name));

  const note = await pudu.invoke('save', { title: ' Hi ', body: 'one two three' });
  check('typed result', note.title === 'Hi' && note.words === 3);

  try {
    await pudu.invoke('save', { title: 4, body: '' });
    check('decode failure', false);
  } catch (problem) {
    check('decode failure', problem.kind === 'invalid-arguments' && problem.path === '.title');
  }

  try {
    await pudu.invoke('save', { title: '  ', body: '' });
    check('handler failure', false);
  } catch (problem) {
    check('handler failure', problem.kind === 'failed' && problem.message === 'a note needs a title');
  }

  try {
    await pudu.invoke('admin:wipe', null);
    check('unknown command', false);
  } catch (problem) {
    check('unknown command', problem.kind === 'unknown-command');
  }

  const seen = [];
  const progress = new pudu.Channel((n) => seen.push(n));
  let closed = false;
  progress.onclose = () => { closed = true; };
  const total = await pudu.invoke('count', { text: 'a b c d' }, { channel: progress });
  check('channel', total === 4 && seen.join(',') === '1,2,3,4' && closed);

  const reversed = await pudu.invoke('reverse', new TextEncoder().encode('abc'));
  check('binary', new TextDecoder().decode(reversed) === 'cba');

  check('bridge frozen', Object.isFrozen(pudu) && !('key' in pudu));

  const forged = await fetch('pudu://app/.pudu/ipc/save', { method: 'POST', body: '{}' });
  check('forged call refused', forged.status === 403);

  const style = getComputedStyle(document.body).backgroundColor;
  check('assets and styles', style === 'rgb(246, 245, 242)');

  await pudu.invoke('checkpoint', { passed, failed });
}

if (location.search.includes('self-test')) selfTest();
