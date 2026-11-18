import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const directory = dirname(fileURLToPath(import.meta.url));
const sampleRate = 48000;
const seconds = 3;
const tone = Buffer.alloc(44 + sampleRate * seconds * 4);
tone.write('RIFF');
tone.writeUInt32LE(tone.length - 8, 4);
tone.write('WAVEfmt ', 8);
tone.writeUInt32LE(16, 16);
tone.writeUInt16LE(1, 20);
tone.writeUInt16LE(2, 22);
tone.writeUInt32LE(sampleRate, 24);
tone.writeUInt32LE(sampleRate * 4, 28);
tone.writeUInt16LE(4, 32);
tone.writeUInt16LE(16, 34);
tone.write('data', 36);
tone.writeUInt32LE(tone.length - 44, 40);
for (let frame = 0; frame < sampleRate * seconds; frame++) {
  const value = Math.round(12000 * Math.sin(2 * Math.PI * 1000 * frame / sampleRate));
  tone.writeInt16LE(value, 44 + frame * 4);
  tone.writeInt16LE(value, 46 + frame * 4);
}
const tonePath = join(directory, 'dist/tone.wav');
await writeFile(tonePath, tone);

const server = createServer(async (request, response) => {
  const path = new URL(request.url, 'http://localhost').pathname;
  if (path === '/') {
    response.setHeader('Content-Type', 'text/html');
    response.end(`<!doctype html><meta charset="utf-8"><title>Slappy capture test</title>
      <button id="test-action">Run capture action</button>
      <script>var Module = {onRuntimeInitialized() {window.testReady = true;}};</script>
      <script src="/capture.js"></script>`);
    return;
  }
  if (!['/capture.js', '/capture.wasm'].includes(path)) {
    response.writeHead(404).end();
    return;
  }
  try {
    response.setHeader('Content-Type', path.endsWith('.wasm')
      ? 'application/wasm' : 'text/javascript');
    response.end(await readFile(join(directory, 'dist', path.slice(1))));
  } catch (error) {
    response.writeHead(500).end(error.message);
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const address = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({
  args: [
    '--use-fake-ui-for-media-stream',
    '--use-fake-device-for-media-stream',
    `--use-file-for-fake-audio-capture=${tonePath}`,
  ],
});
const failures = [];

async function newPage(mode = 'normal') {
  const page = await browser.newPage();
  page.on('pageerror', error => failures.push(error.message));
  await page.addInitScript(({ mode }) => {
    window.testStreams = [];
    window.testContexts = [];
    const AudioContext = window.AudioContext;
    window.AudioContext = class extends AudioContext {
      constructor(...args) {
        super(...args);
        window.testContexts.push(this);
      }
    };
    const getUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    navigator.mediaDevices.getUserMedia = async constraints => {
      if (mode === 'denied') {
        throw new DOMException('Test microphone permission denied.', 'NotAllowedError');
      }
      const stream = await getUserMedia(constraints);
      window.testStreams.push(stream);
      if (mode === 'pending' && window.testStreams.length === 1) {
        return new Promise(resolve => {
          window.releasePermission = () => resolve(stream);
        });
      }
      return stream;
    };
  }, { mode });
  await page.goto(address);
  await page.waitForFunction(() => window.testReady === true);
  return page;
}

async function call(page, name, ...args) {
  if (name === 'open' || name === 'start') {
    await page.evaluate(({ name, args }) => {
      document.getElementById('test-action').onclick = () => {
        window.testResult = Module[`_capture_${name}`](...args);
      };
    }, { name, args });
    await page.locator('#test-action').click();
    return page.evaluate(() => window.testResult);
  }
  return page.evaluate(({ name, args }) => Module[`_capture_${name}`](...args), { name, args });
}

async function errorText(page) {
  return page.evaluate(() => Module.UTF8ToString(Module._capture_error()));
}

async function ready(page) {
  await page.waitForFunction(() => Module._capture_ready() !== 0);
  assert.equal(await call(page, 'ready'), 1, await errorText(page));
}

async function closed(page) {
  await page.waitForFunction(() =>
    window.testStreams.every(stream => stream.getTracks().every(track => track.readyState === 'ended')) &&
    window.testContexts.every(context => context.state === 'closed'));
}

function analyze(bytes, bits, channels, rate) {
  const view = new DataView(Uint8Array.from(bytes).buffer);
  const stride = channels * bits / 8;
  const values = [];
  for (let offset = 0; offset < bytes.length; offset += stride) {
    values.push(bits === 16 ? view.getInt16(offset, true) / 32768 : (view.getUint8(offset) - 128) / 128);
  }
  const first = values.findIndex(value => Math.abs(value) > 0.05);
  assert.ok(first >= 0, 'Captured PCM must contain the synthetic tone.');
  const signal = values.slice(first + 500);
  assert.ok(signal.length > 2000, 'Capture must contain enough frames to measure pitch.');
  let crossings = 0;
  for (let i = 1; i < signal.length; i++) {
    if (signal[i - 1] <= 0 && signal[i] > 0) crossings++;
  }
  const frequency = crossings * rate / signal.length;
  assert.ok(Math.abs(frequency - 1000) < 80, `Expected 1 kHz at ${rate} Hz, got ${frequency.toFixed(1)} Hz.`);
  return frequency;
}

try {
  const page = await newPage();
  for (const [rate, channels, bits] of [
    [24000, 1, 16], [24000, 2, 16], [24000, 1, 8], [24000, 2, 8],
    [44100, 1, 16],
  ]) {
    assert.equal(await call(page, 'open', rate, channels, bits, rate * 2), 1);
    assert.equal(await call(page, 'frequency'), rate);
    assert.equal(await call(page, 'channels'), channels);
    assert.equal(await call(page, 'bits'), bits);
    assert.equal(await call(page, 'start'), 1);
    await ready(page);
    await page.waitForFunction(() => Module._capture_available() >= 12000);
    assert.equal(await call(page, 'stop'), 1);
    await page.waitForFunction(() => Module._capture_stopping() === 0);
    const available = await call(page, 'available');
    assert.equal(await call(page, 'read', 0), 0);
    assert.equal(await call(page, 'available'), available);
    assert.equal(await call(page, 'read', -1), -1);
    assert.equal(await call(page, 'read', available + 1), -1);
    assert.equal(await call(page, 'available'), available);
    assert.equal(await call(page, 'read', 64), 64 * channels * bits / 8);
    assert.equal(await call(page, 'available'), available - 64);
    const before = await page.evaluate(() => Module.HEAPU8.buffer.byteLength);
    assert.equal(await call(page, 'grow'), 32 * 1024 * 1024);
    const after = await page.evaluate(() => Module.HEAPU8.buffer.byteLength);
    assert.ok(after >= before);
    const length = await call(page, 'read_all');
    assert.equal(length, (available - 64) * channels * bits / 8);
    const bytes = await page.evaluate(length => {
      const address = Module._capture_data();
      return Array.from(Module.HEAPU8.subarray(address, address + length));
    }, length);
    const frequency = analyze(bytes, bits, channels, rate);
    assert.equal(await call(page, 'available'), 0);
    assert.equal(await call(page, 'read_all'), 0);
    assert.equal(await call(page, 'close'), 1);
    assert.equal(await call(page, 'close'), 1);
    assert.equal(await call(page, 'ready'), 0);
    assert.equal(await call(page, 'start'), -1);
    assert.equal(await call(page, 'read', 0), -1);
    await closed(page);
    console.log(`Captured ${channels}-channel ${bits}-bit PCM at ${rate} Hz (${frequency.toFixed(1)} Hz tone).`);
  }

  assert.equal(await call(page, 'open', 24000, 1, 16, 24000), 1);
  assert.equal(await call(page, 'start'), 1);
  await ready(page);
  await page.waitForFunction(() => Module._capture_available() > 512);
  const stopResult = await page.evaluate(() => {
    Module._capture_read_all();
    const end = performance.now() + 250;
    while (performance.now() < end) {}
    return Module._capture_stop();
  });
  assert.equal(stopResult, 1);
  await page.waitForFunction(() => Module._capture_stopping() === 0);
  assert.ok(await call(page, 'available') >= 3600,
    'A 250 ms UI stall must retain captured audio through stop and drain.');
  assert.equal(await call(page, 'close'), 1);
  await closed(page);
  console.log('Audio-thread capture survives a rendering stall and drains after stop.');

  assert.equal(await call(page, 'open', 24000, 1, 16, 1024), 1);
  assert.equal(await call(page, 'start'), 1);
  await ready(page);
  await page.waitForFunction(() => Module._capture_available() === 1024);
  await page.waitForTimeout(100);
  assert.equal(await call(page, 'available'), 1024);
  const repeatedStart = await page.evaluate(() => {
    const before = Module._capture_available();
    Module._capture_start();
    return [before, Module._capture_available()];
  });
  assert.deepEqual(repeatedStart, [1024, 1024]);
  assert.equal(await call(page, 'stop'), 1);
  const restarted = await page.evaluate(() => {
    Module._capture_start();
    return Module._capture_available();
  });
  assert.equal(restarted, 0);
  await page.waitForFunction(() => Module._capture_available() > 0);
  assert.equal(await call(page, 'close'), 1);
  await closed(page);
  await page.close();
  console.log('Bounded buffering, partial reads, heap growth, and restart passed.');

  const pending = await newPage('pending');
  assert.equal(await call(pending, 'open', 24000, 1, 16, 24000), 1);
  assert.equal(await call(pending, 'start'), 1);
  await pending.waitForFunction(() => window.releasePermission);
  assert.equal(await call(pending, 'ready'), 0);
  assert.equal(await call(pending, 'available'), 0);
  assert.equal(await call(pending, 'read', 0), 0);
  assert.equal(await call(pending, 'close'), 1);
  await pending.evaluate(() => window.releasePermission());
  await closed(pending);
  assert.equal(await call(pending, 'open', 24000, 1, 16, 24000), 1);
  assert.equal(await call(pending, 'start'), 1);
  await ready(pending);
  await pending.waitForFunction(() => Module._capture_available() > 0);
  assert.equal(await call(pending, 'close'), 1);
  await closed(pending);
  await pending.close();
  console.log('Closing pending permission stops late-granted tracks and permits reopening.');

  const stopped = await newPage('pending');
  assert.equal(await call(stopped, 'open', 24000, 1, 16, 24000), 1);
  assert.equal(await call(stopped, 'start'), 1);
  await stopped.waitForFunction(() => window.releasePermission);
  assert.equal(await call(stopped, 'stop'), 1);
  await stopped.evaluate(() => window.releasePermission());
  await ready(stopped);
  await stopped.waitForTimeout(100);
  assert.equal(await call(stopped, 'available'), 0);
  assert.equal(await call(stopped, 'start'), 1);
  await stopped.waitForFunction(() => Module._capture_available() > 0);
  await stopped.evaluate(() => {
    const track = window.testStreams[0].getAudioTracks()[0];
    track.stop();
    track.dispatchEvent(new Event('ended'));
  });
  await stopped.waitForFunction(() => Module._capture_ready() === -1);
  assert.match(await errorText(stopped), /ended/i);
  assert.equal(await call(stopped, 'close'), 1);
  await closed(stopped);
  await stopped.close();
  console.log('Stop while permission is pending and device disconnection passed.');

  const denied = await newPage('denied');
  assert.equal(await call(denied, 'open', 24000, 1, 16, 24000), 1);
  await denied.waitForFunction(() => Module._capture_ready() === -1);
  assert.match(await errorText(denied), /permission|NotAllowedError|denied/i);
  assert.equal(await call(denied, 'available'), -1);
  assert.equal(await call(denied, 'close'), 1);
  assert.equal(await call(denied, 'close'), 1);
  await closed(denied);
  await denied.close();
  console.log('Permission errors propagate as SlappyError and release browser resources.');

  assert.deepEqual(failures, [], 'Browser execution must not throw unhandled errors.');
  console.log('All browser microphone tests passed using synthetic audio only.');
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
