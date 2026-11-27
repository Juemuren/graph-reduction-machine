import { fromHtml } from "hast-util-from-html";
import assert from "node:assert/strict";
import { base, exampleFiles, html } from "./helpers.ts";

async function playgroundLinks(page: string): Promise<URL[]> {
  const pageUrl = new URL(`${base}/${page}`, "https://site.test");
  const pending = [...fromHtml(await html(page)).children];
  const links: URL[] = [];
  while (pending.length > 0) {
    const node = pending.pop();
    if (node?.type !== "element") continue;
    pending.push(...node.children);
    if (node.tagName !== "a" || typeof node.properties.href !== "string") {
      continue;
    }
    const target = new URL(node.properties.href, pageUrl);
    if (
      target.origin === pageUrl.origin &&
      target.pathname === `${base}/playground/`
    ) {
      links.push(target);
    }
  }
  return links;
}

Deno.test("runnable example source pages link to their playground entry", async () => {
  const sources = JSON.parse(await html("playground/examples.json"));
  for (const { slug, files } of await exampleFiles()) {
    for (const file of files.filter((name) => /\.(lambda|ski)$/.test(name))) {
      const entry = `${slug}/${file}`;
      const source = `examples/${entry}`;
      const links = await playgroundLinks(`${source}/index.html`);
      assert.ok(
        links.some((url) => url.searchParams.get("example") === entry),
        source,
      );
      assert.equal(typeof sources[source], "string", source);
    }
  }
});
