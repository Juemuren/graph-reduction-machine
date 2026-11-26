import { shikiToMonaco } from "@shikijs/monaco";
import * as monaco from "monaco-editor/esm/vs/editor/editor.api.js";
import "monaco-editor/esm/vs/editor/contrib/contextmenu/browser/contextmenu.js";
import "monaco-editor/esm/vs/editor/contrib/documentSymbols/browser/documentSymbols.js";
import "monaco-editor/esm/vs/editor/contrib/find/browser/findController.js";
import "monaco-editor/esm/vs/editor/contrib/gotoError/browser/gotoError.js";
import "monaco-editor/esm/vs/editor/contrib/gotoSymbol/browser/goToCommands.js";
import "monaco-editor/esm/vs/editor/contrib/gotoSymbol/browser/link/goToDefinitionAtPosition.js";
import "monaco-editor/esm/vs/editor/contrib/hover/browser/hoverContribution.js";
import "monaco-editor/esm/vs/editor/contrib/parameterHints/browser/parameterHints.js";
import "monaco-editor/esm/vs/editor/contrib/rename/browser/rename.js";
import "monaco-editor/esm/vs/editor/contrib/semanticTokens/browser/documentSemanticTokens.js";
import "monaco-editor/esm/vs/editor/contrib/suggest/browser/suggestController.js";
import "monaco-editor/esm/vs/editor/standalone/browser/quickAccess/standaloneCommandsQuickAccess.js";
import "monaco-editor/esm/vs/editor/standalone/browser/quickAccess/standaloneGotoSymbolQuickAccess.js";
import "monaco-editor/esm/vs/editor/standalone/browser/referenceSearch/standaloneReferenceSearch.js";
import { createSourceHighlighter, highlightThemes } from "./highlight";

const { editor, languages } = monaco;

export async function createSourceEditor(container: HTMLElement) {
  globalThis.MonacoEnvironment = {
    getWorker: () =>
      new Worker(new URL("./playground-editor.worker.ts", import.meta.url), {
        type: "module",
      }),
  };

  languages.register({ id: "core-lambda" });
  languages.setLanguageConfiguration("core-lambda", {
    comments: { lineComment: "#" },
    brackets: [["(", ")"]],
  });
  languages.register({ id: "ski-graph" });
  languages.setLanguageConfiguration("ski-graph", {
    comments: { lineComment: "--" },
  });
  // HTML highlighting switches themes per render. Keep Monaco's tokenizer separate.
  const integration = { ...monaco, editor: { ...editor } };
  shikiToMonaco(await createSourceHighlighter(), integration);

  const dark = matchMedia("(prefers-color-scheme: dark)");
  const theme = () => highlightThemes[dark.matches ? "dark" : "light"];
  dark.addEventListener("change", () => integration.editor.setTheme(theme()));

  return integration.editor.create(container, {
    model: null,
    "semanticHighlighting.enabled": true,
    ariaLabel: "当前文件源码",
    automaticLayout: true,
    theme: theme(),
    fontSize: 15,
    fontLigatures: false,
    lineHeight: 24,
    minimap: { enabled: false },
    padding: { top: 8, bottom: 8 },
    scrollBeyondLastLine: false,
  });
}

export function createSourceModel(path: string, source: string) {
  const model = editor.createModel(
    source,
    path.endsWith(".ski") ? "ski-graph" : "core-lambda",
    monaco.Uri.from({ scheme: "grm", path: `/${path}` }),
  );
  model.updateOptions({ tabSize: 2, insertSpaces: true });
  return model;
}
