import { build } from 'esbuild';

await build({
  entryPoints: ['client/extension.js'],
  bundle: true,
  platform: 'node',
  format: 'cjs',
  outdir: 'out',
  external: ['vscode'],
});
