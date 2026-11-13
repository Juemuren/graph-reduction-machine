import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { referenceDocs, root } from "../src/config.ts";

export const dist = fileURLToPath(new URL("../dist/", import.meta.url));
export const base = (Deno.env.get("SITE_BASE") ?? "/").replace(/\/$/, "");
export const output = (relative: string) => path.join(dist, relative);
export const html = (relative: string) => readFile(output(relative), "utf8");

export interface ExampleFiles {
  slug: string;
  files: string[];
}

export async function exampleFiles(): Promise<ExampleFiles[]> {
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

export async function markdownPages() {
  return [
    ...referenceDocs.map((slug) => `docs/${slug}/index.html`),
    ...(await exampleFiles()).map(({ slug }) => `examples/${slug}/index.html`),
  ];
}
