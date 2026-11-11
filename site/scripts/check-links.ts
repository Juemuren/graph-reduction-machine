import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const dist = fileURLToPath(new URL("../dist/", import.meta.url));
const base = (Deno.env.get("SITE_BASE") ?? "/").replace(/\/$/, "");
const errors: string[] = [];
async function pages(dir: string): Promise<string[]> {
  return (
    await Promise.all(
      (
        await readdir(dir, { withFileTypes: true })
      ).map(async (entry) => {
        const absolute = path.join(dir, entry.name);
        return entry.isDirectory()
          ? pages(absolute)
          : entry.name.endsWith(".html")
            ? [absolute]
            : [];
      }),
    )
  ).flat();
}
for (const page of await pages(dist)) {
  const html = await readFile(page, "utf8");
  for (const match of html.matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    const url = match[1].replaceAll("&amp;", "&");
    if (/^(?:[a-z][a-z\d+.-]*:|\/\/|#|data:)/i.test(url)) {
      if (!url.startsWith("#")) continue;
    }
    const parsed = new URL(
      url,
      `https://site.test${base}/${path.relative(dist, page).replaceAll("\\", "/")}`,
    );
    if (base && !parsed.pathname.startsWith(`${base}/`)) {
      errors.push(`${path.relative(dist, page)}: link outside site ${url}`);
      continue;
    }
    const pathname = base
      ? parsed.pathname.slice(base.length)
      : parsed.pathname;
    const target = path.join(dist, decodeURIComponent(pathname));
    const candidate = pathname.endsWith("/")
      ? path.join(target, "index.html")
      : target;
    try {
      const result = await stat(candidate);
      if (!result.isFile()) throw new Error("not a file");
      if (parsed.hash && candidate.endsWith(".html")) {
        const targetHtml =
          candidate === page ? html : await readFile(candidate, "utf8");
        const id = decodeURIComponent(parsed.hash.slice(1));
        if (!targetHtml.includes(`id="${id}"`))
          errors.push(`${path.relative(dist, page)}: missing fragment ${url}`);
      }
    } catch {
      errors.push(`${path.relative(dist, page)}: missing target ${url}`);
    }
  }
}
if (errors.length) {
  console.error(errors.join("\n"));
  Deno.exit(1);
} else console.log("All internal links and fragments resolve.");
