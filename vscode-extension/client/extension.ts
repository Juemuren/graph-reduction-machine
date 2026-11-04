import * as path from 'node:path';
import type * as vscode from 'vscode';
import { LanguageClient, TransportKind } from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  const module = context.asAbsolutePath(path.join('out', 'server', 'server.js'));
  client = new LanguageClient(
    'skiGraph',
    'SKI Graph Language Server',
    { run: { module, transport: TransportKind.ipc }, debug: { module, transport: TransportKind.ipc } },
    { documentSelector: [{ scheme: 'file', language: 'ski-graph' }, { scheme: 'untitled', language: 'ski-graph' }] }
  );
  await client.start();
}

export async function deactivate(): Promise<void> {
  await client?.dispose();
  client = undefined;
}
