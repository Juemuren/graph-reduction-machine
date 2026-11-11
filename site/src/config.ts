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

// Insertion order determines the order of known examples on the index.
export const exampleNames: Record<string, string> = {
  lambda: "λ 演算",
  ski: "SKI 图",
  encoding: "编码",
  fibonacci: "斐波那契",
  pi: "圆周率",
  e: "自然常数",
  calculus: "符号微积分",
};
