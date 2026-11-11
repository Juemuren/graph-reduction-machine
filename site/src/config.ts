import path from "node:path";

// Site tasks run from site/, so content is read from the parent repository.
export const root = path.resolve(process.cwd(), "..");

// Documents shown in /docs/ and accepted as internal Markdown links.
export const referenceDocs = [
  "syntax",
  "architecture",
  "compiler",
  "interpreter",
  "lsp",
  "lib",
];

// Known examples appear in this order; new examples follow by directory name.
export const exampleOrder = [
  "lambda",
  "ski",
  "encoding",
  "fibonacci",
  "pi",
  "e",
  "calculus",
];
