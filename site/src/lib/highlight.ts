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
    themes: ["catppuccin-latte", "catppuccin-mocha"],
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
  const lines = tokenizer.codeToTokensWithThemes(text, {
    lang: (extension === "lambda"
      ? "core-lambda"
      : "ski-graph") as BundledLanguage,
    themes: { light: "catppuccin-latte", dark: "catppuccin-mocha" },
  });
  return lines.map((tokens) =>
    tokens
      .map((token) => {
        const content = escapeHtml(token.content);
        const light = token.variants.light?.color;
        const dark = token.variants.dark?.color;
        return light && dark
          ? `<span style="--token-light:${light};--token-dark:${dark}">${content}</span>`
          : content;
      })
      .join(""),
  );
}
