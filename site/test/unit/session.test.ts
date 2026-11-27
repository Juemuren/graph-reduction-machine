import assert from "node:assert/strict";
import { sessionPath } from "../../src/lib/playground/session.ts";
import { parsePreset } from "../../src/lib/playground/settings.ts";

Deno.test("session paths are relative and remain inside the workspace", () => {
  assert.equal(sessionPath("group/../main.lambda"), "main.lambda");
  assert.equal(sessionPath("../outside.lambda"), undefined);
  assert.equal(sessionPath("/main.lambda"), undefined);
});

Deno.test("presets require applicable fields and ignore inapplicable fields", () => {
  assert.deepEqual(
    parsePreset("main.ski", {
      stage: "decode",
      decode: "pair<natural, list<boolean>>",
      steps: 100,
      reduction: "none",
    }),
    { stage: "decode", decode: "pair<natural, list<boolean>>", steps: 100 },
  );
  assert.throws(
    () => parsePreset("main.ski", { stage: "compile" }),
    /不支持/,
  );
  assert.throws(
    () =>
      parsePreset("main.ski", { stage: "decode", decode: "real", steps: 100 }),
    /缺少字段 precision/,
  );
  assert.throws(
    () =>
      parsePreset("main.ski", {
        stage: "decode",
        decode: "pair<natural>",
        steps: 100,
      }),
    /字段 decode 的值无效/,
  );
  assert.throws(
    () => parsePreset("main.ski", { stage: "interpret", steps: 100.5 }),
    /字段 steps 的值无效/,
  );
  assert.throws(
    () => parsePreset("main.ski", { stage: "interpret", step: 100 }),
    /未知字段 step/,
  );
  assert.throws(
    () =>
      parsePreset("main.lambda", {
        stage: "compile",
        natural: "church",
        string: "church<binary>",
      }),
    /缺少字段 reduction/,
  );
});
