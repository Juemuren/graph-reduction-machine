import { readFile } from "node:fs/promises";
import path from "node:path";
import { type BundledLanguage, createHighlighter } from "shiki";
import { root } from "../config";

const escapeHtml = (value: string) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");

const highlighter = Promise.all([
  readFile(
    path.join(root, "vscode-extension/syntaxes/core-lambda.tmLanguage.json"),
    "utf8",
  ),
  readFile(
    path.join(root, "vscode-extension/syntaxes/ski-graph.tmLanguage.json"),
    "utf8",
  ),
]).then(([lambda, ski]) =>
  createHighlighter({
    langs: [
      { ...JSON.parse(lambda), name: "core-lambda" },
      { ...JSON.parse(ski), name: "ski-graph" },
    ],
    themes: ["github-dark"],
  }),
);

export async function highlightedLines(
  source: string,
  extension: string,
): Promise<string[]> {
  const text = source.replace(/\n$/, "");
  if (extension !== "lambda" && extension !== "ski")
    return text.split("\n").map(escapeHtml);

  const tokenizer = await highlighter;
  const lines = tokenizer.codeToTokens(text, {
    lang: (extension === "lambda"
      ? "core-lambda"
      : "ski-graph") as BundledLanguage,
    theme: "github-dark",
  }).tokens;
  return lines.map((tokens) =>
    tokens
      .map((token) => {
        const content = escapeHtml(token.content);
        return token.color
          ? `<span style="color:${token.color}">${content}</span>`
          : content;
      })
      .join(""),
  );
}
