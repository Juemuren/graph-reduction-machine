import assert from "node:assert/strict";
import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { referenceDocs, root } from "../src/config.ts";

const site = fileURLToPath(new URL("../", import.meta.url));
const dist = path.join(site, "dist");
const output = (relative: string) => path.join(dist, relative);
const html = (relative: string) => readFile(output(relative), "utf8");
const base = (Deno.env.get("SITE_BASE") ?? "/").replace(/\/$/, "");

interface ExampleFiles {
  slug: string;
  files: string[];
}

async function exampleFiles(): Promise<ExampleFiles[]> {
  const entries = await readdir(path.join(root, "examples"), {
    withFileTypes: true,
  });
  const directories = entries.filter((entry) => entry.isDirectory());
  const contents = await Promise.all(
    directories.map(async ({ name }) => ({
      slug: name,
      files: await readdir(path.join(root, "examples", name)),
    })),
  );
  return contents.filter(({ files }) => files.includes("README.md"));
}

async function markdownPages() {
  return [
    ...referenceDocs.map((slug) => `docs/${slug}/index.html`),
    ...(await exampleFiles()).map(({ slug }) => `examples/${slug}/index.html`),
  ];
}

Deno.test("internal navigation and images use the deployment base", async () => {
  const index = await html("index.html");
  assert.ok(index.includes(`href="${base}/examples/"`));
  assert.ok(index.includes(`href="${base}/docs/"`));

  for (const page of await markdownPages()) {
    const content = await html(page);
    for (const [, source] of content.matchAll(/<img\b[^>]*\bsrc="([^"]+)"/g)) {
      if (source.startsWith("/")) {
        assert.ok(source.startsWith(`${base}/`), `${page}: ${source}`);
      }
    }
  }
});

Deno.test("content root resolves to the repository", async () => {
  assert.equal(root, path.resolve(site, ".."));
  assert.ok((await stat(path.join(root, "examples"))).isDirectory());
});

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

Deno.test("global stylesheet provides Latte and Mocha colors", async () => {
  const index = await html("index.html");
  const stylesheet = index.match(/href="([^"]+\.css)"/);
  assert.ok(stylesheet);
  const css = await html(stylesheet[1].replace(`${base}/`, ""));
  assert.match(css, /--base:\s*#eff1f5/);
  assert.match(css, /--base:\s*#1e1e2e/);
  assert.match(css, /prefers-color-scheme:\s*dark/);
});

Deno.test("configured documents and library sources have pages", async () => {
  for (const slug of referenceDocs) {
    assert.match(await html(`docs/${slug}/index.html`), /<article\b/);
  }

  const library = (await readdir(path.join(root, "lib"))).filter((file) =>
    file.endsWith(".lambda")
  );
  assert.ok(library.length > 0);
  const index = await html("docs/lib/index.html");
  for (const file of library) {
    assert.ok(index.includes(`${base}/lib/${file}/`), file);
    assert.match(await html(`lib/${file}/index.html`), /id="copy-source"/);
  }
});

Deno.test("desktop and mobile TOCs list the article headings", async () => {
  for (const page of await markdownPages()) {
    const content = await html(page);
    const article = content.match(/<article\b[^>]*>([\s\S]*?)<\/article>/);
    assert.ok(article, `${page} has an article`);
    const headingIds = [
      ...article[1].matchAll(/<h[2-6]\b[^>]*\bid="([^"]+)"/g),
    ].map((match) => match[1]);
    const fragmentNavigations = [
      ...content.matchAll(/<nav\b[^>]*>([\s\S]*?)<\/nav>/g),
    ]
      .map((match) =>
        [...match[1].matchAll(/href="#([^"]+)"/g)].map((link) => link[1])
      )
      .filter((ids) => ids.length > 0);
    assert.deepEqual(
      fragmentNavigations,
      headingIds.length > 0 ? [headingIds, headingIds] : [],
      page,
    );
    if (headingIds.length > 0) {
      assert.match(content, /class="toc-trigger"[^>]*aria-haspopup="dialog"/);
      assert.match(content, /<dialog\b[^>]*id="mobile-toc"/);
    }
  }
});
