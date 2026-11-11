import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { root } from "../src/config.ts";

const dist = fileURLToPath(new URL("../dist/", import.meta.url));
const output = (relative: string) => path.join(dist, relative);
const html = (relative: string) => readFile(output(relative), "utf8");
const base = (Deno.env.get("SITE_BASE") ?? "/").replace(/\/$/, "");

Deno.test("internal navigation uses the deployment base", async () => {
  const index = await html("index.html");
  assert.ok(index.includes(`href="${base}/examples/"`));
  assert.ok(index.includes(`href="${base}/docs/"`));
  const example = await html("examples/pi/index.html");
  assert.ok(example.includes(`src="${base}/assets/examples/pi/`));
});

Deno.test("content root resolves to the repository in dev and build", async () => {
  assert.equal(path.basename(root), "graph-reduction-machine");
  assert.ok((await stat(path.join(root, "examples"))).isDirectory());
});

Deno.test("seven examples are linked from the index and have readable pages", async () => {
  const index = await html("examples/index.html");
  for (
    const slug of [
      "lambda",
      "ski",
      "encoding",
      "fibonacci",
      "pi",
      "e",
      "calculus",
    ]
  ) {
    assert.match(index, new RegExp(`/examples/${slug}/`));
    assert.match(await html(`examples/${slug}/index.html`), /class="prose"/);
  }
});

Deno.test("math, comparison image and data are present in the generated site", async () => {
  const page = await html("examples/pi/index.html");
  assert.match(page, /class="katex"/);
  assert.match(page, /assets\/examples\/pi\/steps-vs-error\.png/);
  assert.ok(
    (await stat(output("assets/examples/pi/steps-vs-error.png"))).size > 0,
  );
  assert.ok(
    (await stat(output("assets/examples/pi/steps-vs-error.csv"))).size > 0,
  );
});

Deno.test("source pages have line numbers, copy and raw download", async () => {
  const page = await html("examples/pi/arctan.lambda/index.html");
  assert.match(page, /class="code-line/);
  assert.match(page, /id="copy-source"/);
  assert.match(page, /assets\/examples\/pi\/arctan\.lambda/);
  assert.ok((await stat(output("assets/examples/pi/arctan.lambda"))).size > 0);
  assert.match(
    page,
    /style="--token-light:#[0-9A-Fa-f]{6};--token-dark:#[0-9A-Fa-f]{6}"/,
  );
});

Deno.test("global stylesheet provides Latte and Mocha colors", async () => {
  const index = await html("index.html");
  const stylesheet = index.match(/href="([^"]+\.css)"/);
  assert.ok(stylesheet);
  const css = await html(stylesheet[1].replace(`${base}/`, ""));
  assert.match(css, /--base:\s*#eff1f5/);
  assert.match(css, /--base:\s*#1e1e2e/);
  assert.match(css, /prefers-color-scheme:\s*dark/);
});

Deno.test("architecture, document links and standard library source resolve", async () => {
  const compiler = await html("docs/compiler/index.html");
  assert.match(compiler, /\/docs\/architecture\/#/);
  assert.match(await html("docs/architecture/index.html"), /<article/);
  assert.match(
    await html("docs/lib/index.html"),
    /\/lib\/combinator\.lambda\//,
  );
  assert.match(
    await html("lib/combinator.lambda/index.html"),
    /id="copy-source"/,
  );
});
