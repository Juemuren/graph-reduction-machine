import type { APIRoute } from "astro";
import { assetFiles, readSource } from "../../lib/content";

export const GET: APIRoute = async () => {
  const paths = (await assetFiles()).filter((file) =>
    /^(?:examples|lib)\/.*\.(?:lambda|ski)$/.test(file),
  );
  return Response.json(
    Object.fromEntries(
      await Promise.all(
        paths.map(async (file) => [file, await readSource(file)]),
      ),
    ),
  );
};
