import assert from "node:assert/strict";
import { readdir } from "node:fs/promises";
import path from "node:path";
import { referenceDocs, root } from "../src/config.ts";
import { base, html, markdownPages } from "./helpers.ts";

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
