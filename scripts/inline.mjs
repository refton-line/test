import { readFile, writeFile, readdir } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const dist = path.join(root, 'dist');

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { cwd: root, stdio: 'inherit', shell: process.platform === 'win32' });
    p.on('exit', code => code === 0 ? resolve() : reject(new Error(`${cmd} exited with ${code}`)));
    p.on('error', reject);
  });
}

await run('npx', ['vite', 'build']);

const assets = path.join(dist, 'assets');
const files = await readdir(assets);
const jsFiles = files.filter(f => f.endsWith('.js'));
let html = await readFile(path.join(dist, 'index.html'), 'utf8');

for (const f of files.filter(n => n.endsWith('.css'))) {
  const css = await readFile(path.join(assets, f), 'utf8');
  html = html.replace(new RegExp(`<link[^>]*href="[^"]*${f}"[^>]*>`), '');
  html = html.replace('</head>', () => `<style>\n${css}\n</style>\n</head>`);
}

for (const f of jsFiles) {
  const js = await readFile(path.join(assets, f), 'utf8').catch(() => '');
  if (!js) continue;
  html = html.replace(new RegExp(`<script[^>]*src="[^"]*${f}"[^>]*></script>`), () => `<script type="module">\n${js}\n</script>`);
}

if (/<(script|link)[^>]+(src|href)="\/assets\//.test(html)) {
  throw new Error('inline: an asset reference is still left in dist/index.html');
}

await writeFile(path.join(dist, 'index.html'), html);
console.log(`inline: dist/index.html is self-contained (${(html.length / 1024).toFixed(0)} KB)`);
