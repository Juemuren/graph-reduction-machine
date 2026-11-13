import assert from "node:assert/strict";
import { stat } from "node:fs/promises";
import { referenceDocs } from "../src/config.ts";
import { base, html, output } from "./helpers.ts";

Deno.test("Pagefind indexes Chinese content and loads only on the search page", async () => {
  const index = await html("index.html");
  const search = await html("search/index.html");
  const document = await html(`docs/${referenceDocs[0]}/index.html`);
  const entry = JSON.parse(await html("pagefind/pagefind-entry.json"));

  assert.match(index, /<main\b[^>]*data-pagefind-body/);
  assert.match(document, /<main\b[^>]*data-pagefind-body/);
  assert.doesNotMatch(search, /<main\b[^>]*data-pagefind-body/);
  assert.ok(search.includes(`bundle-path="${base}/pagefind/"`));
  assert.ok(search.includes(`base-url="${base}/"`));
  assert.ok(search.includes(`src="${base}/pagefind/pagefind-component-ui.js"`));
  assert.ok(
    search.includes(`href="${base}/pagefind/pagefind-component-ui.css"`),
  );
  assert.doesNotMatch(index, /pagefind-component-ui/);
  assert.ok(entry.languages["zh-cn"].page_count >= referenceDocs.length);
  assert.ok((await stat(output("pagefind/pagefind-component-ui.js"))).size > 0);
});
