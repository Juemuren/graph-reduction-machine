const assert = require('node:assert/strict');
const test = require('node:test');
const { tokenizeFixture, scopesAt, assertScope } = require('./utils.cjs');

test('highlights directives, definitions, lambda parameters, names, and numbers', async () => {
  const fixture = await tokenizeFixture('highlights.lambda');

  assertScope(fixture, 0, '@<', 'keyword.control.import.core-lambda');
  assertScope(fixture, 0, 'value', 'variable.other.core-lambda');
  assertScope(fixture, 1, '@>', 'keyword.control.export.core-lambda');
  assertScope(fixture, 1, 'exported', 'entity.name.function.definition.core-lambda');
  assertScope(fixture, 1, 'param', 'variable.parameter.core-lambda');
  assertScope(fixture, 1, 'ADD', 'support.function.builtin.core-lambda');
  assertScope(fixture, 1, '12', 'constant.numeric.integer.core-lambda');
  assertScope(fixture, 2, '@!', 'keyword.control.entry.core-lambda');
});

test('keeps punctuation and comments inside an import path in the string scope', async () => {
  const fixture = await tokenizeFixture('import-path.lambda');

  for (const text of ['#b.lambda', ';#b']) {
    assertScope(fixture, 0, text, 'string.quoted.double.core-lambda');
  }
  assertScope(fixture, 0, String.raw`\"`, 'constant.character.escape.core-lambda');
  assertScope(fixture, 0, 'value', 'variable.other.core-lambda');
  assertScope(fixture, 0, 'value', 'meta.statement.import.core-lambda');
  assertScope(fixture, 0, ');', 'punctuation.core-lambda');
});

test('a missing semicolon does not extend a directive over the next definition', async () => {
  for (const name of ['missing-import', 'missing-export', 'missing-entry']) {
    const fixture = await tokenizeFixture(`${name}.lambda`);
    const scopes = scopesAt(fixture, 1, 'next');

    assertScope(fixture, 1, 'next', 'entity.name.function.definition.core-lambda');
    assert(!scopes.some(scope => scope.startsWith('meta.statement.')), name);
  }
});
