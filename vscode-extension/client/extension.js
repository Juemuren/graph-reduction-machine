import { LanguageClient } from 'vscode-languageclient/node';

let client;

export async function activate() {
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

export async function deactivate() {
  await client?.dispose();
  client = undefined;
}
