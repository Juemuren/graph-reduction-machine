const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const { test } = require('node:test');
const { createMessageConnection, StreamMessageReader, StreamMessageWriter } = require('vscode-jsonrpc/node');

const serverPath = path.join(__dirname, '..', 'out', 'server', 'server.js');

async function withServer(run) {
  const server = spawn(process.execPath, [serverPath, '--stdio'], { stdio: ['pipe', 'pipe', 'pipe'] });
  let stderr = '';
  server.stderr.setEncoding('utf8').on('data', chunk => { stderr += chunk; });
  const connection = createMessageConnection(new StreamMessageReader(server.stdout), new StreamMessageWriter(server.stdin));
  connection.listen();
  try {
    const initialization = await connection.sendRequest('initialize', { processId: process.pid, rootUri: null, capabilities: {} });
    connection.sendNotification('initialized', {});
    await run(connection, initialization);
  } catch (error) {
    if (stderr) error.message += `\nLanguage server stderr:\n${stderr}`;
    throw error;
  } finally {
    connection.dispose();
    server.kill();
  }
}

function open(connection, uri, languageId, text) {
  connection.sendNotification('textDocument/didOpen', { textDocument: { uri, languageId, version: 1, text } });
}

function complete(connection, uri, line, character) {
  return connection.sendRequest('textDocument/completion', { textDocument: { uri }, position: { line, character } });
}

function hover(connection, uri, line, character) {
  return connection.sendRequest('textDocument/hover', { textDocument: { uri }, position: { line, character } });
}

test('SKI completes defined nodes and hovers their definitions', { timeout: 5000 }, async () => {
  await withServer(async (connection, initialization) => {
    assert.deepEqual(initialization.capabilities.completionProvider.triggerCharacters, ['#']);
    assert.equal(initialization.capabilities.hoverProvider, true);

    const uri = 'file:///ski-lsp-test.ski';
    open(connection, uri, 'ski-graph', '#0 = #1 #2;\n#1 = I;\n#2 = K;\n-- #9 = S;\n#3 = #');
    const items = await complete(connection, uri, 4, 6);
    assert.deepEqual(items.map(item => item.label), ['#0', '#1', '#2']);
    assert.deepEqual(items[1].textEdit, {
      range: { start: { line: 4, character: 5 }, end: { line: 4, character: 6 } },
      newText: '#1'
    });
    assert.match((await hover(connection, uri, 0, 6)).contents.value, /#1 = I/);
    assert.equal(await hover(connection, uri, 3, 4), null);
  });
});

test('Core Lambda completes visible names and explains definitions and imports', { timeout: 5000 }, async () => {
  await withServer(async connection => {
    const uri = 'file:///lambda-lsp-test.lambda';
    const lines = [
      '@< "./defs.lambda" (remote, EXTERNAL);',
      'name = \\x -> x;',
      'forward = la;',
      'later = \\bar -> name (remote b);',
      'after = b;',
      'shadow = \\name -> name;',
      '@! ID;',
      '# fake = name'
    ];
    open(connection, uri, 'core-lambda', lines.join('\n'));

    const labels = async (line, character) => (await complete(connection, uri, line, character)).map(item => item.label);
    assert.ok((await labels(2, lines[2].indexOf('la;') + 2)).includes('later'));
    assert.ok((await labels(3, lines[3].indexOf('rem') + 3)).includes('remote'));
    assert.ok((await labels(3, lines[3].indexOf('b);') + 1)).includes('bar'));
    assert.ok(!(await labels(4, lines[4].indexOf('b;') + 1)).includes('bar'));
    assert.deepEqual(await labels(6, lines[6].indexOf('ID') + 2), []);

    assert.match((await hover(connection, uri, 3, lines[3].indexOf('name'))).contents.value, /name = \\x -> x;/);
    assert.match((await hover(connection, uri, 3, lines[3].indexOf('remote'))).contents.value, /\.\/defs\.lambda/);
    assert.equal((await hover(connection, uri, 5, lines[5].lastIndexOf('name'))).contents.value, '参数 name');
    assert.equal(await hover(connection, uri, 7, lines[7].indexOf('name')), null);

    const changed = lines.slice();
    changed[6] = '@! added;';
    changed.push('added = I;');
    connection.sendNotification('textDocument/didChange', {
      textDocument: { uri, version: 2 },
      contentChanges: [{ text: changed.join('\n') }]
    });
    assert.ok((await labels(6, changed[6].indexOf('added') + 2)).includes('added'));
  });
});
