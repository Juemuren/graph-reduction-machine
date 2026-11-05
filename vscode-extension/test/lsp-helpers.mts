import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import type { MessageConnection } from 'vscode-jsonrpc';
import jsonrpc from 'vscode-jsonrpc/node.js';

const { createMessageConnection, StreamMessageReader, StreamMessageWriter } = jsonrpc;

const serverPath = fileURLToPath(new URL('../out/server/server.js', import.meta.url));

type Initialization = {
  capabilities: {
    completionProvider: { triggerCharacters: string[] };
    hoverProvider: boolean;
  };
};
type Completion = { label: string; textEdit?: unknown };
type Hover = { contents: { value: string } };

export async function loadFixture(name: string): Promise<{ uri: string; text: string }> {
  const url = new URL(`./fixtures/${name}`, import.meta.url);
  return { uri: url.href, text: await readFile(url, 'utf8') };
}

export async function withServer(
  run: (connection: MessageConnection, initialization: Initialization) => Promise<void>,
): Promise<void> {
  const server = spawn(process.execPath, [serverPath, '--stdio'], {
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let stderr = '';
  server.stderr.setEncoding('utf8').on('data', (chunk: string) => {
    stderr += chunk;
  });
  const connection = createMessageConnection(
    new StreamMessageReader(server.stdout),
    new StreamMessageWriter(server.stdin),
  );
  connection.listen();
  try {
    const initialization = await connection.sendRequest<Initialization>('initialize', {
      processId: process.pid,
      rootUri: null,
      capabilities: {},
    });
    connection.sendNotification('initialized', {});
    await run(connection, initialization);
  } catch (error) {
    if (stderr && error instanceof Error) error.message += `\nLanguage server stderr:\n${stderr}`;
    throw error;
  } finally {
    connection.dispose();
    server.kill();
  }
}

export function open(
  connection: MessageConnection,
  uri: string,
  languageId: string,
  text: string,
): void {
  connection.sendNotification('textDocument/didOpen', {
    textDocument: { uri, languageId, version: 1, text },
  });
}

export function complete(
  connection: MessageConnection,
  uri: string,
  line: number,
  character: number,
): Promise<Completion[]> {
  return connection.sendRequest<Completion[]>('textDocument/completion', {
    textDocument: { uri },
    position: { line, character },
  });
}

export function hover(
  connection: MessageConnection,
  uri: string,
  line: number,
  character: number,
): Promise<Hover | null> {
  return connection.sendRequest<Hover | null>('textDocument/hover', {
    textDocument: { uri },
    position: { line, character },
  });
}

export async function hoverText(
  connection: MessageConnection,
  uri: string,
  line: number,
  character: number,
): Promise<string | null> {
  return (await hover(connection, uri, line, character))?.contents.value ?? null;
}
