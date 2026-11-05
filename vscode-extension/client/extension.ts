import type * as vscode from 'vscode';
import { LanguageClient } from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export async function activate(_context: vscode.ExtensionContext): Promise<void> {
  client = new LanguageClient(
    'graphReductionMachine',
    'Graph Reduction Machine Language Server',
    { command: 'graph-reduction-machine-lsp' },
    {
      documentSelector: [
        { scheme: 'file', language: 'core-lambda' },
        { scheme: 'untitled', language: 'core-lambda' },
        { scheme: 'file', language: 'ski-graph' },
        { scheme: 'untitled', language: 'ski-graph' },
      ],
    },
  );
  await client.start();
}

export async function deactivate(): Promise<void> {
  await client?.dispose();
  client = undefined;
}
