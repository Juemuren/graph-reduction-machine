const assert = require('node:assert/strict');
const test = require('node:test');
const { tokenizeFixture: tokenizeFixtureFor, scopesAt, assertScope } = require('./utils.cjs');
const tokenizeFixture = tokenizeFixtureFor('source.core-lambda');

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
  for (const directive of ['import', 'export', 'entry']) {
    for (const [suffix, name] of [['', 'next'], ['-uppercase', 'NEXT']]) {
      const fixture = await tokenizeFixture(`missing-${directive}${suffix}.lambda`);
      const scopes = scopesAt(fixture, 1, name);

      assertScope(fixture, 1, name, 'entity.name.function.definition.core-lambda');
      assert(!scopes.some(scope => scope.startsWith('meta.statement.')), `${directive}: ${name}`);
    }
  }
});

test('highlights uppercase definitions and statements on the same line', async () => {
  const fixture = await tokenizeFixture('same-line.lambda');

  for (const name of ['UPPER', 'lower']) {
    assertScope(fixture, 0, name, 'entity.name.function.definition.core-lambda');
  }
  assertScope(fixture, 0, '@<', 'keyword.control.import.core-lambda');
  assertScope(fixture, 0, 'IMPORTED', 'meta.statement.import.core-lambda');
  assertScope(fixture, 0, '@>', 'keyword.control.export.core-lambda');
  assertScope(fixture, 0, 'EXPORTED', 'entity.name.function.definition.core-lambda');
  assertScope(fixture, 0, '@!', 'keyword.control.entry.core-lambda');
});
