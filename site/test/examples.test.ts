import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { root } from "../src/config.ts";
import { base, exampleFiles, html, markdownPages, output } from "./helpers.ts";

Deno.test("every example README has a linked, readable page", async () => {
  const examples = await exampleFiles();
  assert.ok(examples.length > 0);
  const index = await html("examples/index.html");
  for (const { slug } of examples) {
    assert.ok(index.includes(`href="${base}/examples/${slug}/"`), slug);
    assert.match(await html(`examples/${slug}/index.html`), /class="prose"/);
  }
});

Deno.test("Markdown math and example data appear in the generated site", async () => {
  const pages = await Promise.all((await markdownPages()).map(html));
  assert.ok(pages.some((page) => page.includes('class="katex"')));

  const examples = await exampleFiles();
  const assets = examples.flatMap(({ slug, files }) =>
    files
      .filter((file) => /\.(png|csv)$/.test(file))
      .map((file) => `assets/examples/${slug}/${file}`)
  );
  assert.ok(assets.length > 0);
  for (const asset of assets) {
    assert.ok((await stat(output(asset))).size > 0, asset);
  }
});

Deno.test("Markdown images are linked as a navigable lightbox gallery", async () => {
  for (const { slug, files } of await exampleFiles()) {
    const imageFiles = files.filter((file) => file.endsWith(".png"));
    const page = await html(`examples/${slug}/index.html`);
    const images = [
      ...page.matchAll(
        /<a href="([^"]+\.png)" data-pswp-width="(\d+)" data-pswp-height="(\d+)"><img src="\1" alt="[^"]*"><\/a>/g,
      ),
    ];
    assert.equal(images.length, imageFiles.length, slug);
    for (const [, href, width, height] of images) {
      assert.ok(href.startsWith(`${base}/assets/examples/${slug}/`), href);
      const relative = href.slice(`${base}/assets/`.length);
      const bytes = await readFile(path.join(root, relative));
      assert.equal(Number(width), bytes.readUInt32BE(16), href);
      assert.equal(Number(height), bytes.readUInt32BE(20), href);
    }
  }
});

Deno.test("local CSV links keep downloads and render tables", async () => {
  for (const { slug, files } of await exampleFiles()) {
    const page = await html(`examples/${slug}/index.html`);
    for (const file of files.filter((name) => name.endsWith(".csv"))) {
      const link = `href="${base}/assets/examples/${slug}/${file}"`;
      const position = page.indexOf(link);
      assert.ok(position >= 0, `${slug}/${file}: download link`);
      assert.match(
        page.slice(position),
        /^href="[^"]+"[^>]*>[^<]*<\/a><\/p>\s*<details class="csv-table-details"><summary>查看表格（\d+ 行）<\/summary><table>/,
      );
    }
  }
});

Deno.test("every source page has line numbers, copy and raw download", async () => {
  const examples = await exampleFiles();
  const sources = examples.flatMap(({ slug, files }) =>
    files
      .filter((file) => /\.(lambda|ski)$/.test(file))
      .map((file) => ({ slug, file }))
  );
  assert.ok(sources.length > 0);
  let foundHighlight = false;
  for (const { slug, file } of sources) {
    const page = await html(`examples/${slug}/${file}/index.html`);
    assert.match(page, /class="code-line/);
    assert.match(page, /id="copy-source"/);
    assert.ok(page.includes(`${base}/assets/examples/${slug}/${file}`));
    assert.ok((await stat(output(`assets/examples/${slug}/${file}`))).size > 0);
    foundHighlight ||= /--token-light:#[0-9A-Fa-f]{6}/.test(page);
  }
  assert.ok(foundHighlight, "source syntax highlighting is present");
});
