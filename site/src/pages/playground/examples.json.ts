import type { APIRoute } from "astro";
import { examples, readSource } from "../../lib/content";
import { sessionPath } from "../../lib/playground/session";

export const GET: APIRoute = async () => {
  const groups = (await examples()).filter(({ files }) =>
    files.includes("playground.json"),
  );
  return Response.json(
    Object.fromEntries(
      await Promise.all(
        groups.map(async ({ slug, files }) => {
          const folder = `examples/${slug}/`;
          const config = JSON.parse(
            await readSource(`${folder}playground.json`),
          );
          const paths = files.filter((file) => sessionPath(file) === file);
          if (!paths.includes(config.entry)) {
            throw new Error(`${folder}playground.json: 默认入口不存在`);
          }
          return [
            slug,
            {
              entry: folder + config.entry,
              presets: config.presets ?? {},
              files: await Promise.all(
                paths.map(async (file) => {
                  const path = folder + file;
                  return [path, await readSource(path)];
                }),
              ),
            },
          ];
        }),
      ),
    ),
  );
};
