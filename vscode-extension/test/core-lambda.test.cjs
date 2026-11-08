const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const textmate = require('vscode-textmate');
const oniguruma = require('vscode-oniguruma');

const grammarPath = path.join(__dirname, '../syntaxes/core-lambda.tmLanguage.json');
const grammarPromise = (async () => {
  const wasm = fs.readFileSync(require.resolve('vscode-oniguruma/release/onig.wasm'));
  await oniguruma.loadWASM(wasm.buffer.slice(wasm.byteOffset, wasm.byteOffset + wasm.byteLength));
  const registry = new textmate.Registry({
    onigLib: Promise.resolve({
      createOnigScanner: patterns => new oniguruma.OnigScanner(patterns),
      createOnigString: source => new oniguruma.OnigString(source),
    }),
    loadGrammar: async () => textmate.parseRawGrammar(fs.readFileSync(grammarPath, 'utf8'), grammarPath),
  });
  return registry.loadGrammar('source.core-lambda');
})();

async function tokenize(lines) {
  const grammar = await grammarPromise;
  let stack = textmate.INITIAL;
  return lines.map(line => {
    const result = grammar.tokenizeLine(line, stack);
    stack = result.ruleStack;
    return result.tokens;
  });
}

function scopesAt(line, tokens, text) {
  const index = line.indexOf(text);
  assert.notEqual(index, -1, `Missing test text: ${text}`);
  const token = tokens.find(({ startIndex, endIndex }) => startIndex <= index && index < endIndex);
  assert(token, `No token at ${text}`);
  return token.scopes;
}

test('highlights directives, definitions, lambda parameters, names, and numbers', async () => {
  const lines = [
    '@< "./lib.lambda" (value, ADD);',
    String.raw`@> exported = \param -> ADD param 12;`,
    '@! exported;',
  ];
  const tokens = await tokenize(lines);
  assert(scopesAt(lines[0], tokens[0], '@<').includes('keyword.control.import.core-lambda'));
  assert(scopesAt(lines[0], tokens[0], 'value').includes('variable.other.core-lambda'));
  assert(scopesAt(lines[1], tokens[1], '@>').includes('keyword.control.export.core-lambda'));
  assert(scopesAt(lines[1], tokens[1], 'exported').includes('entity.name.function.definition.core-lambda'));
  assert(scopesAt(lines[1], tokens[1], 'param').includes('variable.parameter.core-lambda'));
  assert(scopesAt(lines[1], tokens[1], 'ADD').includes('support.function.builtin.core-lambda'));
  assert(scopesAt(lines[1], tokens[1], '12').includes('constant.numeric.integer.core-lambda'));
  assert(scopesAt(lines[2], tokens[2], '@!').includes('keyword.control.entry.core-lambda'));
});

test('keeps punctuation and comments inside an import path in the string scope', async () => {
  const line = String.raw`@< "./a\";#b.lambda" (value);`;
  const [tokens] = await tokenize([line]);
  for (const text of ['#b.lambda', ';#b']) {
    assert(scopesAt(line, tokens, text).includes('string.quoted.double.core-lambda'));
  }
  assert(scopesAt(line, tokens, String.raw`\"`).includes('constant.character.escape.core-lambda'));
  assert(scopesAt(line, tokens, 'value').includes('variable.other.core-lambda'));
  assert(scopesAt(line, tokens, 'value').includes('meta.statement.import.core-lambda'));
  assert(scopesAt(line, tokens, ');').includes('punctuation.core-lambda'));
});

test('a missing semicolon does not extend a directive over the next definition', async () => {
  for (const directive of ['@< "./lib.lambda" (value)', '@> exported = 1', '@! exported']) {
    const lines = [directive, 'next = 2;'];
    const tokens = await tokenize(lines);
    const scopes = scopesAt(lines[1], tokens[1], 'next');
    assert(scopes.includes('entity.name.function.definition.core-lambda'), directive);
    assert(!scopes.some(scope => scope.startsWith('meta.statement.')), directive);
  }
});
