import assert from 'node:assert/strict';
import { test } from 'node:test';
import { complete, hover, hoverText, loadFixture, open, withServer } from './lsp-helpers.mts';

test('Core Lambda completes visible names and explains definitions and imports', {
  timeout: 5000,
}, async () => {
  await withServer(async (connection) => {
    const { uri, text } = await loadFixture('lambda/lambda-lsp-test.lambda');
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

    const { text: changedText } = await loadFixture('lambda/lambda-lsp-changed.lambda');
    const changed = changedText.split(/\r?\n/);
    connection.sendNotification('textDocument/didChange', {
      textDocument: { uri, version: 2 },
      contentChanges: [{ text: changedText }],
    });
    assert.ok((await labels(6, changed[6].indexOf('added') + 2)).includes('added'));
  });
});
