import { build } from 'esbuild';

await build({
  entryPoints: ['client/extension.ts', 'server/server.ts'],
  bundle: true,
  platform: 'node',
  format: 'cjs',
  outdir: 'out',
  external: ['vscode'],
});
