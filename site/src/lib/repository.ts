import path from "node:path";

// Site tasks run from site/, so content is read from the parent repository.
export const root = path.resolve(process.cwd(), "..");
