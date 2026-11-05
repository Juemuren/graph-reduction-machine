import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import type { MessageConnection } from 'vscode-jsonrpc';
import jsonrpc from 'vscode-jsonrpc/node.js';

const { createMessageConnection, StreamMessageReader, StreamMessageWriter } = jsonrpc;

const serverPath = fileURLToPath(new URL('../out/server/server.js', import.meta.url));

async function loadFixture(name: string): Promise<{ uri: string; text: string }> {
  const url = new URL(`./fixtures/${name}`, import.meta.url);
  return { uri: url.href, text: await readFile(url, 'utf8') };
}

type Initialization = {
  capabilities: {
    completionProvider: { triggerCharacters: string[] };
    hoverProvider: boolean;
  };
};
type Completion = { label: string; textEdit?: unknown };
type Hover = { contents: { value: string } };

async function withServer(
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

async function hoverText(
  connection: MessageConnection,
  uri: string,
  line: number,
  character: number,
): Promise<string | null> {
  return (await hover(connection, uri, line, character))?.contents.value ?? null;
}

function open(connection: MessageConnection, uri: string, languageId: string, text: string): void {
  connection.sendNotification('textDocument/didOpen', {
    textDocument: { uri, languageId, version: 1, text },
  });
}

function complete(
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

function hover(
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

test('SKI completes defined nodes and hovers their definitions', { timeout: 5000 }, async () => {
  await withServer(async (connection, initialization) => {
    assert.deepEqual(initialization.capabilities.completionProvider.triggerCharacters, ['#']);
    assert.equal(initialization.capabilities.hoverProvider, true);

    const { uri, text } = await loadFixture('ski-lsp-test.ski');
    open(connection, uri, 'ski-graph', text);
    const items = await complete(connection, uri, 4, 6);
    assert.deepEqual(
      items.map((item) => item.label),
      ['#0', '#1', '#2'],
    );
    assert.deepEqual(items[1].textEdit, {
      range: { start: { line: 4, character: 5 }, end: { line: 4, character: 6 } },
      newText: '#1',
    });
    assert.match((await hoverText(connection, uri, 0, 6)) ?? '', /#1 = I/);
    assert.equal(await hover(connection, uri, 3, 4), null);
  });
});

test('Core Lambda completes visible names and explains definitions and imports', {
  timeout: 5000,
}, async () => {
  await withServer(async (connection) => {
    const { uri, text } = await loadFixture('lambda-lsp-test.lambda');
    const lines = text.split(/\r?\n/);
    open(connection, uri, 'core-lambda', text);

    const labels = async (line: number, character: number) =>
      (await complete(connection, uri, line, character)).map((item) => item.label);
    assert.ok((await labels(2, lines[2].indexOf('la;') + 2)).includes('later'));
    assert.ok((await labels(3, lines[3].indexOf('rem') + 3)).includes('remote'));
    assert.ok((await labels(3, lines[3].indexOf('b);') + 1)).includes('bar'));
    assert.ok(!(await labels(4, lines[4].indexOf('b;') + 1)).includes('bar'));
    assert.deepEqual(await labels(6, lines[6].indexOf('ID') + 2), []);

    assert.match(
      (await hoverText(connection, uri, 3, lines[3].indexOf('name'))) ?? '',
      /name = \\x -> x;/,
    );
    assert.match(
      (await hoverText(connection, uri, 3, lines[3].indexOf('remote'))) ?? '',
      /\.\/defs\.lambda/,
    );
    assert.equal(await hoverText(connection, uri, 5, lines[5].lastIndexOf('name')), '参数 name');
    assert.equal(await hover(connection, uri, 7, lines[7].indexOf('name')), null);

    const { text: changedText } = await loadFixture('lambda-lsp-changed.lambda');
    const changed = changedText.split(/\r?\n/);
    connection.sendNotification('textDocument/didChange', {
      textDocument: { uri, version: 2 },
      contentChanges: [{ text: changedText }],
    });
    assert.ok((await labels(6, changed[6].indexOf('added') + 2)).includes('added'));
  });
});
