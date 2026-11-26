import latte from "@shikijs/themes/catppuccin-latte";
import mocha from "@shikijs/themes/catppuccin-mocha";
import { createHighlighterCore } from "shiki/core";
import { createJavaScriptRegexEngine } from "shiki/engine/javascript";
import lambda from "../../../vscode-extension/syntaxes/core-lambda.tmLanguage.json" with {
  type: "json",
};
import ski from "../../../vscode-extension/syntaxes/ski-graph.tmLanguage.json" with {
  type: "json",
};

const escapeHtml = (value: string) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");

const highlighter = createHighlighterCore({
  langs: [
    { ...lambda, name: "core-lambda" },
    { ...ski, name: "ski-graph", repository: {} },
  ],
  themes: [latte, mocha],
  engine: createJavaScriptRegexEngine(),
});

export async function highlightedLines(
  source: string,
  extension: string,
  trimFinalNewline = true,
): Promise<string[]> {
  const text = trimFinalNewline ? source.replace(/\n$/, "") : source;
  if (extension !== "lambda" && extension !== "ski")
    return text.split("\n").map(escapeHtml);

  const tokenizer = await highlighter;
  const lines = tokenizer.codeToTokensWithThemes(text, {
    lang: extension === "lambda" ? "core-lambda" : "ski-graph",
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
