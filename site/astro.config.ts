import { defineConfig } from "astro/config";

export default defineConfig({
  base: process.env.SITE_BASE ?? "/",
  output: "static",
  trailingSlash: "ignore",
  build: { format: "directory" },
  vite: {
    build: {
      // The minified playground entry, including Monaco, is about 3.36 MB.
      chunkSizeWarningLimit: 5000,
    },
  },
});
