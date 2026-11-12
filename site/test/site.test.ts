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

Deno.test("every page links to the published favicon", async () => {
  const favicon = await html("favicon.svg");
  assert.match(favicon, /<svg\b/);
  for (const page of ["index.html", ...(await markdownPages())]) {
    assert.ok(
      (await html(page)).includes(
        `<link rel="icon" type="image/svg+xml" href="${base}/favicon.svg">`,
      ),
      page,
    );
  }
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
