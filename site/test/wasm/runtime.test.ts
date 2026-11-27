import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import type {
  RunMessage,
  RunRequest,
} from "../../src/lib/playground/session.ts";
import { runPlayground } from "../../src/lib/playground/runtime.ts";

const defaults: RunRequest = {
  entry: "main.lambda",
  files: [],
  stage: "decode",
  reduction: "none",
  natural: "church",
  string: "church<binary>",
  decode: "natural",
  precision: 0,
  steps: 100_000,
};

Deno.test("Playground WASM resolves a relative import and a standard-library builtin", async () => {
  const messages: RunMessage[] = [];
  await runPlayground({
    ...defaults,
    entry: "src/main.lambda",
    files: [
      [
        "src/main.lambda",
        '@< "../lib/helper.lambda" (number);\n@! ADD number 3;',
      ],
      ["lib/helper.lambda", "@> number = 2;"],
    ],
  }, async (program) => {
    const file = new URL(
      `../../public/playground/${program}.wasm`,
      import.meta.url,
    );
    return WebAssembly.compile(await readFile(file));
  }, (message) => messages.push(message));

  const result = messages.at(-1);
  assert.ok(result && "output" in result, JSON.stringify(messages));
  assert.equal(result.stage, "decode");
  assert.equal(result.output, "5");
});
