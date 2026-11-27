import assert from "node:assert/strict";
import {
  exampleSession,
  sessionPath,
} from "../../src/lib/playground/session.ts";

Deno.test("session paths are relative and example dependencies are transitive", () => {
  assert.equal(sessionPath("group/../main.lambda"), "main.lambda");
  assert.equal(sessionPath("../outside.lambda"), undefined);
  assert.equal(sessionPath("/main.lambda"), undefined);
  const files = exampleSession("examples/a/main.lambda", {
    "examples/a/main.lambda":
      '# @< "./ignored.lambda" (ignored);\n@< "../b/helper.lambda" (helper);\n@! helper;',
    "examples/b/helper.lambda":
      '@< "./base.lambda" (value);\n@> helper = value;',
    "examples/b/base.lambda": "@> value = 2;",
    "examples/a/ignored.lambda": "@> ignored = 0;",
  });
  assert.deepEqual([...files.keys()], [
    "examples/a/main.lambda",
    "examples/b/helper.lambda",
    "examples/b/base.lambda",
  ]);
});
