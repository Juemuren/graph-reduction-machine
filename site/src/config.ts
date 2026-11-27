import type { Stage } from "./lib/playground/session";

// Documents shown in /docs/ and accepted as internal Markdown links.
export const docNames = [
  "syntax",
  "architecture",
  "compiler",
  "interpreter",
  "lsp",
  "lib",
];

// Known examples appear in this order; new examples follow by directory name.
export const exampleNames = [
  "lambda",
  "ski",
  "natural",
  "list",
  "string",
  "real",
  "fibonacci",
  "pi",
  "e",
  "calculus",
];

export const runTimeoutMs = 10_000;
export const inputLimit = 1024 * 1024;
export const outputLimit = 2 * 1024 * 1024;

export const stageLabels: Record<Stage, string> = {
  expand: "展开",
  reduce: "归约",
  compile: "编译",
  interpret: "解释",
  decode: "解码",
};
