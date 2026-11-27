import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  analyzeSource,
  type LanguageRequest,
  type LanguageResults,
} from "../../src/lib/playground/language-protocol.ts";

const module = readFile(
  new URL("../../public/playground/language-service.wasm", import.meta.url),
).then((bytes) => WebAssembly.compile(bytes));

function fixture(name: string) {
  return readFile(
    new URL(`../../../test/cases/lsp/${name}`, import.meta.url),
    "utf8",
  );
}

async function analyze<K extends keyof LanguageResults>(
  operation: K,
  path: string,
  source: string,
  args: string[] = [],
  files: LanguageRequest["files"] = [],
) {
  return await analyzeSource(await module, {
    operation,
    path: `/${path}`,
    source,
    files,
    args,
  }) as LanguageResults[K];
}

Deno.test("Core Lambda WASM agrees with the native LSP fixtures", async () => {
  const path = "src/main.lambda";
  const source = (await fixture("main.lambda")).replace(
    "./defs.lambda",
    "../lib/defs.lambda",
  );
  const imports: LanguageRequest["files"] = [
    ["lib/defs.lambda", await fixture("defs.lambda")],
  ];
  const completion = await analyze("completion", path, source, ["3", "16"]);
  assert.ok(
    completion.some(([label, , detail, docs]) =>
      label === "name" && detail === "x" && docs?.includes("name =")
    ),
  );
  const hover = await analyze("hover", path, source, ["3", "25"], imports);
  assert.match(hover?.[0] ?? "", /@> remote = .*value/);
  const updated: LanguageRequest["files"] = [[
    "lib/defs.lambda",
    "\n@> remote = \\updated -> updated;",
  ]];
  const definition = await analyze(
    "definition",
    path,
    source,
    ["3", "25"],
    updated,
  );
  assert.equal(
    new URL(definition?.[0] ?? "/", "file:///").pathname,
    "/lib/defs.lambda",
  );
  assert.equal(definition?.[1][0], 1);
  const updatedHover = await analyze(
    "hover",
    path,
    source,
    ["3", "25"],
    updated,
  );
  assert.match(updatedHover?.[0] ?? "", /remote = .*updated/);
  assert.match(
    (await analyze("hover", path, source, ["6", "4"]))?.[0] ?? "",
    /@> ID =/,
  );
  assert.deepEqual(
    new Set((await analyze("tokens", path, source)).map(([, kind]) => kind)),
    new Set([7, 8]),
  );
  assert.equal(
    (await analyze("references", path, source, ["1", "1"])).length,
    2,
  );
  assert.ok(
    (await analyze("symbols", path, source)).some(([name]) => name === "later"),
  );
  const diagnostics = await analyze("diagnostics", path, source);
  assert.ok(
    diagnostics.some(([, message]) => message.includes("Undefined name: la")),
  );
  assert.equal(await analyze("prepareRename", path, source, ["3", "25"]), null);
  const rename = await analyze(
    "rename",
    "rename.lambda",
    await fixture("rename.lambda"),
    ["0", "1", "renamed"],
  );
  assert.deepEqual(rename, ["renamed", [[0, 0, 0, 3], [1, 3, 1, 6]]]);
  const signature = await analyze(
    "signature",
    "signature.lambda",
    await fixture("signature.lambda"),
    ["1", "11"],
  );
  assert.deepEqual(signature, ["pair", ["x", "y"], 1]);
});

Deno.test("SKI WASM agrees with the native LSP fixtures", async () => {
  const path = "rename.ski";
  const source = await fixture(path);
  assert.deepEqual(await analyze("definition", path, source, ["0", "6"]), [
    "/rename.ski",
    [1, 0, 1, 2],
  ]);
  assert.match(
    (await analyze("hover", path, source, ["0", "6"]))?.[0] ?? "",
    /#1 = I/,
  );
  assert.ok(
    (await analyze("completion", path, source, ["0", "6"])).some(([name]) =>
      name === "#1"
    ),
  );
  assert.equal(
    (await analyze("references", path, source, ["0", "7"])).length,
    3,
  );
  assert.deepEqual(
    (await analyze("symbols", path, source)).map(([name]) => name),
    ["#0", "#1"],
  );
  assert.deepEqual(await analyze("prepareRename", path, source, ["0", "7"]), [
    0,
    5,
    0,
    7,
  ]);
  assert.equal(await analyze("prepareRename", path, source, ["0", "1"]), null);
  const rename = await analyze("rename", path, source, ["0", "7", "2"]);
  assert.equal(rename?.[0], "#2");
  assert.equal(rename?.[1].length, 3);
  assert.equal(await analyze("rename", path, source, ["0", "7", "#0"]), null);
  const diagnostics = await analyze(
    "diagnostics",
    "invalid.ski",
    await fixture("invalid.ski"),
  );
  assert.deepEqual(
    new Set(diagnostics.map(([, message]) => message)),
    new Set(["Duplicate node: #1", "Undefined node: #2"]),
  );
});
