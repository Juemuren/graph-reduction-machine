import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { docNames, exampleNames } from "../../src/config.ts";
import { root } from "../../src/lib/repository.ts";

export const dist = fileURLToPath(new URL("../../dist/", import.meta.url));
export const base = (Deno.env.get("SITE_BASE") ?? "/").replace(/\/$/, "");
export const output = (relative: string) => path.join(dist, relative);
export const html = (relative: string) => readFile(output(relative), "utf8");

export interface ExampleFiles {
  slug: string;
  files: string[];
}

export function exampleFiles(): Promise<ExampleFiles[]> {
  return Promise.all(
    exampleNames.map(async (slug) => ({
      slug,
      files: await readdir(path.join(root, "examples", slug)),
    })),
  );
}

export async function markdownPages() {
  return [
    ...docNames.map((slug) => `docs/${slug}/index.html`),
    ...(await exampleFiles()).map(({ slug }) => `examples/${slug}/index.html`),
  ];
}
