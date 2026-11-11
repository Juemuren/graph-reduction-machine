import { readFile } from "node:fs/promises";
import path from "node:path";
import type { APIRoute } from "astro";
import { assetFiles, root } from "../../lib/content";

export async function getStaticPaths() {
  return (await assetFiles()).map((name) => ({
    params: { path: name },
    props: { name },
  }));
}

export const GET: APIRoute = async ({ props }) => {
  const name = props.name as string;
  const type = name.endsWith(".png")
    ? "image/png"
    : name.endsWith(".csv")
      ? "text/csv; charset=utf-8"
      : name.endsWith(".json")
        ? "application/json; charset=utf-8"
        : "text/plain; charset=utf-8";
  return new Response(await readFile(path.join(root, name)), {
    headers: {
      "Content-Type": type,
      "Content-Disposition": name.endsWith(".png")
        ? "inline"
        : `attachment; filename="${path.basename(name)}"`,
    },
  });
};
