import assert from "node:assert/strict";
import {
  completeDecode,
  validDecode,
} from "../../src/lib/playground/decode-type.ts";

Deno.test("completes a nested type and places the caret in its first argument", () => {
  const input = "pair<natural, scott-list<pa>>";
  const cursor = input.indexOf("pa>>") + 2;
  assert.deepEqual(completeDecode(input, cursor), [{
    label: "pair<, >",
    text: "pair<, >",
    start: cursor - 2,
    end: cursor,
    cursor: cursor + 3,
  }]);
});

Deno.test("replaces the whole name and preserves the existing arguments", () => {
  const input = "pair<lst<natural>, boolean>";
  assert.deepEqual(completeDecode(input, 6), [{
    label: "list<>",
    text: "list",
    start: 5,
    end: 8,
    cursor: 10,
  }]);
});

Deno.test("offers only types and encodings allowed at the caret", () => {
  assert.deepEqual(completeDecode("re", 2).map(({ text }) => text), [
    "real",
    "real:",
  ]);
  assert.deepEqual(
    completeDecode("list<re>", 7).map(({ text }) => text),
    ["real", "real:"],
  );
  assert.deepEqual(
    completeDecode("list<string:church<b>>", 20).map(({ text }) => text),
    ["binary"],
  );
  assert.deepEqual(
    completeDecode("pair<natural, >", 14).map(({ text }) => text).includes(
      "boolean",
    ),
    true,
  );
});

Deno.test("completes an explicit string decoder and preserves its colon", () => {
  const input = "list<str:scott<binary>>";
  assert.deepEqual(completeDecode(input, 8), [{
    label: "string:",
    text: "string",
    start: 5,
    end: 8,
    cursor: 12,
  }]);
  assert.deepEqual(
    completeDecode("string:", 7).map(({ text }) => text),
    ["church<>", "scott<>"],
  );
});

Deno.test("offers missing delimiters without duplicating existing ones", () => {
  assert.equal(completeDecode("pair<natural ", 13)[0]?.text, ", ");
  assert.equal(completeDecode("list<natural ", 13)[0]?.text, ">");
  assert.deepEqual(completeDecode("list<natural >", 13), []);
});

Deno.test("validates complete decode types using the same grammar", () => {
  assert.equal(
    validDecode("pair<list<natural>, scott-list<string:church<binary>> >"),
    true,
  );
  assert.equal(validDecode("real"), true);
  assert.equal(validDecode("pair<real, list<real:12>>"), true);
  assert.equal(validDecode("real:"), false);
  assert.equal(validDecode("real:-1"), false);
  assert.equal(validDecode("real: 1"), false);
  assert.equal(validDecode("pair<, >"), false);
  assert.equal(validDecode("string: church<binary>"), false);
  assert.equal(validDecode("list<natural>>"), false);
});
