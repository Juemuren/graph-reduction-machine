const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const textmate = require("vscode-textmate");
const oniguruma = require("vscode-oniguruma");

const grammarPath = path.join(
  __dirname,
  "../syntaxes/core-lambda.tmLanguage.json",
);

const grammarPromise = (async () => {
  const wasm = fs.readFileSync(
    require.resolve("vscode-oniguruma/release/onig.wasm"),
  );
  await oniguruma.loadWASM(
    wasm.buffer.slice(wasm.byteOffset, wasm.byteOffset + wasm.byteLength),
  );
  const registry = new textmate.Registry({
    onigLib: Promise.resolve({
      createOnigScanner: (patterns) => new oniguruma.OnigScanner(patterns),
      createOnigString: (source) => new oniguruma.OnigString(source),
    }),
    loadGrammar: async () =>
      textmate.parseRawGrammar(
        fs.readFileSync(grammarPath, "utf8"),
        grammarPath,
      ),
  });
  return registry.loadGrammar("source.core-lambda");
})();

async function tokenizeFixture(name) {
  const source = fs.readFileSync(
    path.join(__dirname, "fixtures", name),
    "utf8",
  );
  const lines = source.split(/\r?\n/);
  if (lines.at(-1) === "") lines.pop();

  const grammar = await grammarPromise;
  let stack = textmate.INITIAL;
  const tokens = lines.map((line) => {
    const result = grammar.tokenizeLine(line, stack);
    stack = result.ruleStack;
    return result.tokens;
  });
  return { lines, tokens };
}

function scopesAt({ lines, tokens }, lineIndex, text) {
  const index = lines[lineIndex].indexOf(text);
  assert.notEqual(
    index,
    -1,
    `Missing test text on line ${lineIndex + 1}: ${text}`,
  );
  const token = tokens[lineIndex].find(
    ({ startIndex, endIndex }) => startIndex <= index && index < endIndex,
  );
  assert(token, `No token on line ${lineIndex + 1} at ${text}`);
  return token.scopes;
}

function assertScope(fixture, lineIndex, text, scope) {
  assert(
    scopesAt(fixture, lineIndex, text).includes(scope),
    `Expected ${text} on line ${lineIndex + 1} to have scope ${scope}`,
  );
}

module.exports = { tokenizeFixture, scopesAt, assertScope };
