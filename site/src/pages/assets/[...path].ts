import { readFile } from "node:fs/promises";
import path from "node:path";
import type { APIRoute } from "astro";
import { root } from "../../config";
import { assetFiles } from "../../lib/content";

const contentTypes: Record<string, string> = {
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".csv": "text/csv; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

export async function getStaticPaths() {
  return (await assetFiles()).map((name) => ({
    params: { path: name },
    props: { name },
  }));
}

export const GET: APIRoute = async ({ props }) => {
  const name = props.name as string;
  const extension = path.extname(name);
  const type = contentTypes[extension] ?? "text/plain; charset=utf-8";
  return new Response(await readFile(path.join(root, name)), {
    headers: {
      "Content-Type": type,
      "Content-Disposition":
        extension === ".png" || extension === ".svg"
          ? "inline"
          : `attachment; filename="${path.basename(name)}"`,
    },
  });
};
