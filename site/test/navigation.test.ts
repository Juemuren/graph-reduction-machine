import assert from "node:assert/strict";
import { base, html, markdownPages } from "./helpers.ts";

Deno.test("internal navigation and images use the deployment base", async () => {
  const index = await html("index.html");
  assert.ok(index.includes(`href="${base}/examples/"`));
  assert.ok(index.includes(`href="${base}/docs/"`));
  assert.ok(index.includes(`href="${base}/search/"`));

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
