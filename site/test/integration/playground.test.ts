import { fromHtml } from "hast-util-from-html";
import assert from "node:assert/strict";
import { parsePreset } from "../../src/lib/playground/settings.ts";
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

Deno.test("example pages open the entire playground group with a configured entry", async () => {
  const groups = JSON.parse(await html("playground/examples.json"));
  for (const { slug, files } of await exampleFiles()) {
    const folder = `examples/${slug}`;
    const links = await playgroundLinks(`${folder}/index.html`);
    assert.ok(
      links.some((url) => url.searchParams.get("example") === slug),
      slug,
    );

    const group = groups[slug];
    const sources = files.filter((name) => /\.(lambda|ski)$/.test(name));
    const imported = new Map<string, string>(group.files);
    assert.deepEqual(
      [...imported.keys()].sort(),
      sources.map((file) => `${folder}/${file}`).sort(),
    );
    assert.ok(imported.has(group.entry), slug);
    for (const [file, preset] of Object.entries(group.presets)) {
      const path = `${folder}/${file}`;
      assert.ok(imported.has(path), path);
      assert.doesNotThrow(() => parsePreset(path, preset), path);
    }
    for (const source of imported.keys()) {
      const sourceLinks = await playgroundLinks(`${source}/index.html`);
      assert.ok(
        sourceLinks.every((url) => !url.searchParams.has("example")),
        source,
      );
    }
  }
});
