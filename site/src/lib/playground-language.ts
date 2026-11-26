import * as monaco from "monaco-editor/esm/vs/editor/editor.api.js";
import { inputLimit, runTimeoutMs } from "../config";
import { sessionPath } from "./playground";
import type {
  LanguageRequest,
  LanguageResults,
  SourceRange,
} from "./playground-language-protocol";
import { sitePath } from "./urls";

const { editor, languages } = monaco;

function range([line, column, endLine, endColumn]: SourceRange) {
  return new monaco.Range(line + 1, column + 1, endLine + 1, endColumn + 1);
}

export function connectLanguageService(
  sourceEditor: monaco.editor.IStandaloneCodeEditor,
  readFiles: () => Map<string, string>,
  openFile: (path: string) => void,
  getModel: (path: string) => monaco.editor.ITextModel,
  report: (message: string) => void,
) {
  type Model = monaco.editor.ITextModel;
  let worker: Worker | undefined;
  let queue = Promise.resolve();
  let workspaceVersion = 0;
  let diagnosticsTimer: ReturnType<typeof setTimeout> | undefined;
  const encoder = new TextEncoder();

  function execute(request: LanguageRequest): Promise<unknown> {
    return new Promise((resolve, reject) => {
      worker ??= new Worker(
        new URL("./playground-language.worker.ts", import.meta.url),
        { type: "module" },
      );
      const active = worker;
      function fail(message: string) {
        clearTimeout(timer);
        active.terminate();
        worker = undefined;
        reject(new Error(message));
      }
      const timer = setTimeout(() => fail("分析超时"), runTimeoutMs);
      active.onerror = () => fail("分析工作线程异常");
      active.onmessageerror = () => fail("无法读取分析结果");
      active.onmessage = ({ data }) => {
        clearTimeout(timer);
        if (data.error) reject(new Error(data.error));
        else resolve(data.result);
      };
      active.postMessage({ ...request, wasmBase: sitePath("/playground/") });
    });
  }

  function request<K extends keyof LanguageResults>(
    operation: K,
    model: Model,
    token?: monaco.CancellationToken,
    position?: monaco.Position,
    newName?: string,
  ): Promise<LanguageResults[K] | undefined> {
    const version = model.getVersionId();
    const workspace = workspaceVersion;
    const workspaceOperation =
      model.getLanguageId() === "core-lambda" &&
      (operation === "hover" || operation === "definition");
    function current() {
      return (
        !token?.isCancellationRequested &&
        !model.isDisposed() &&
        model.getVersionId() === version &&
        (!workspaceOperation || workspace === workspaceVersion)
      );
    }

    const task = queue.then(async () => {
      if (!current()) return;
      const path = model.uri.path;
      const source = model.getValue(monaco.editor.EndOfLinePreference.LF);
      const files = workspaceOperation ? [...readFiles()] : [];
      let bytes = files.length ? 0 : encoder.encode(source).byteLength;
      for (const [, content] of files)
        bytes += encoder.encode(content).byteLength;
      if (bytes > inputLimit) {
        report("语言服务的源码大小已超出上限。");
        return;
      }
      const args = position
        ? [String(position.lineNumber - 1), String(position.column - 1)]
        : [];
      if (newName !== undefined) args.push(newName);
      try {
        const result = await execute({ operation, path, source, files, args });
        if (current()) {
          report("");
          return result as LanguageResults[K];
        }
      } catch (error) {
        if (current()) report(`语言服务异常 · ${(error as Error).message}`);
      }
    });
    queue = task.then(
      () => {},
      () => {},
    );
    return task;
  }

  function refreshDiagnostics() {
    clearTimeout(diagnosticsTimer);
    const model = sourceEditor.getModel();
    if (!model) return;
    const version = model.getVersionId();
    editor.setModelMarkers(model, "graph-reduction-machine", []);
    diagnosticsTimer = setTimeout(async () => {
      if (sourceEditor.getModel() !== model) return;
      const issues = await request("diagnostics", model);
      if (!issues || model.isDisposed() || model.getVersionId() !== version)
        return;
      editor.setModelMarkers(
        model,
        "graph-reduction-machine",
        issues.map(([selection, message]) => ({
          ...range(selection),
          message,
          source: "graph-reduction-machine",
          severity: monaco.MarkerSeverity.Error,
        })),
      );
    }, 250);
  }

  sourceEditor.onDidChangeModel(refreshDiagnostics);
  sourceEditor.onDidChangeModelContent(refreshDiagnostics);

  editor.registerEditorOpener({
    openCodeEditor(target, resource, selection) {
      if (
        target !== sourceEditor ||
        resource.scheme !== "grm" ||
        !readFiles().has(resource.path.slice(1))
      )
        return false;
      openFile(resource.path.slice(1));
      if (selection && "startLineNumber" in selection) {
        target.setSelection(selection);
        target.revealRangeInCenter(selection);
      } else if (selection && "lineNumber" in selection) {
        target.setPosition(selection);
        target.revealPositionInCenter(selection);
      }
      target.focus();
      return true;
    },
  });

  for (const language of ["core-lambda", "ski-graph"]) {
    languages.registerCompletionItemProvider(language, {
      triggerCharacters: language === "ski-graph" ? ["#"] : [],
      async provideCompletionItems(model, position, _context, token) {
        const items = await request("completion", model, token, position);
        return {
          suggestions: (items ?? []).map(
            ([label, kind, detail, docs, selection]) => ({
              label,
              kind:
                kind === 6
                  ? languages.CompletionItemKind.Variable
                  : languages.CompletionItemKind.Function,
              detail: detail ?? undefined,
              documentation: docs ? { value: docs } : undefined,
              insertText: label,
              range: range(selection),
            }),
          ),
        };
      },
    });
    languages.registerHoverProvider(language, {
      async provideHover(model, position, token) {
        const result = await request("hover", model, token, position);
        if (result)
          return { contents: [{ value: result[0] }], range: range(result[1]) };
      },
    });
    languages.registerDefinitionProvider(language, {
      async provideDefinition(model, position, token) {
        const result = await request("definition", model, token, position);
        if (!result) return;
        const [path, selection] = result;
        const file = sessionPath(path.slice(1));
        if (file && readFiles().has(file)) {
          return { uri: getModel(file).uri, range: range(selection) };
        }
      },
    });
    languages.registerReferenceProvider(language, {
      async provideReferences(model, position, _context, token) {
        return (
          (await request("references", model, token, position)) ?? []
        ).map((selection) => ({ uri: model.uri, range: range(selection) }));
      },
    });
    languages.registerDocumentSymbolProvider(language, {
      async provideDocumentSymbols(model, token) {
        return ((await request("symbols", model, token)) ?? []).map(
          ([name, selection]) => ({
            name,
            detail: "",
            kind: languages.SymbolKind.Variable,
            tags: [],
            range: range(selection),
            selectionRange: range(selection),
          }),
        );
      },
    });
    languages.registerRenameProvider(language, {
      async resolveRenameLocation(model, position, token) {
        const result = await request("prepareRename", model, token, position);
        if (!result) {
          return {
            range: monaco.Range.fromPositions(position),
            text: "",
            rejectReason: "此处无法重命名。",
          };
        }
        const selection = range(result);
        return { range: selection, text: model.getValueInRange(selection) };
      },
      async provideRenameEdits(model, position, newName, token) {
        const versionId = model.getVersionId();
        const result = await request("rename", model, token, position, newName);
        if (!result)
          return { edits: [], rejectReason: "无法使用该名称重命名。" };
        const [text, selections] = result;
        return {
          edits: selections.map((selection) => ({
            resource: model.uri,
            versionId,
            textEdit: { range: range(selection), text },
          })),
        };
      },
    });
  }

  languages.registerSignatureHelpProvider("core-lambda", {
    signatureHelpTriggerCharacters: [" "],
    signatureHelpRetriggerCharacters: [" "],
    async provideSignatureHelp(model, position, token) {
      const result = await request("signature", model, token, position);
      if (!result) return;
      const [name, parameters, activeParameter] = result;
      return {
        value: {
          signatures: [
            {
              label: [name, ...parameters].join(" "),
              parameters: parameters.map((label) => ({ label })),
            },
          ],
          activeSignature: 0,
          activeParameter,
        },
        dispose() {},
      };
    },
  });

  languages.registerDocumentSemanticTokensProvider("core-lambda", {
    getLegend: () => ({
      tokenTypes: ["variable.parameter", "entity.name.function"],
      tokenModifiers: [],
    }),
    async provideDocumentSemanticTokens(model, _lastResultId, token) {
      const tokens = await request("tokens", model, token);
      if (!tokens) return null;
      let previousLine = 0;
      let previousColumn = 0;
      return {
        data: Uint32Array.from(
          tokens.flatMap(([[line, column, , end], kind]) => {
            const delta = [
              line - previousLine,
              line === previousLine ? column - previousColumn : column,
              end - column,
              kind - 7,
              0,
            ];
            previousLine = line;
            previousColumn = column;
            return delta;
          }),
        ),
      };
    },
    releaseDocumentSemanticTokens() {},
  });

  return () => {
    workspaceVersion++;
  };
}
