import { inputLimit, runTimeoutMs, stageLabels } from "../../config";
import { highlightedLines } from "../highlight";
import { sitePath } from "../urls";
import { createSourceEditor, createSourceModel } from "./editor";
import { connectLanguageService } from "./language";
import {
  exampleSession,
  type RunMessage,
  type RunRequest,
  type Stage,
  sessionPath,
} from "./session";

export async function startPlayground() {
  const element = <T extends HTMLElement>(id: string) =>
    document.getElementById(id) as T;
  const editor = await createSourceEditor(element("source"));
  const fileTree = element<HTMLUListElement>("files");
  const sidebar = element("file-sidebar");
  const toggleFiles = element<HTMLButtonElement>("toggle-files");
  const loadExample = element<HTMLSelectElement>("load-example");
  const activeFile = element("active-file");
  const newFile = element<HTMLButtonElement>("new-file");
  const advanced = element("advanced-settings");
  const toggleSettings = element<HTMLButtonElement>("toggle-settings");
  const results = element<HTMLDetailsElement>("results");
  const runSettings = element<HTMLFormElement>("run-settings");
  const addFile = element<HTMLFormElement>("add-file");
  const pathInput = element<HTMLInputElement>("file-path");
  const fileError = element("file-error");
  const removeFile = document.createElement("button");
  removeFile.type = "button";
  removeFile.className = "file-delete";
  removeFile.textContent = "×";
  const stage = element<HTMLSelectElement>("stage");
  const decode = element<HTMLInputElement>("decode");
  const compiler = element<HTMLFieldSetElement>("compiler-options");
  const interpreter = element<HTMLFieldSetElement>("interpreter-options");
  const precision = element<HTMLInputElement>("precision");
  const steps = element<HTMLInputElement>("steps");
  const run = element<HTMLButtonElement>("run");
  const cancel = element<HTMLButtonElement>("cancel");
  const status = element("run-status");
  const output = element("output");
  const stepCount = element("step-count");

  let files = new Map([["main.lambda", "@! ADD 2 3;"]]);
  const models = new Map<string, ReturnType<typeof createSourceModel>>();
  const viewStates = new Map<string, ReturnType<typeof editor.saveViewState>>();
  let activePath = "main.lambda";
  const fileButtons = new Map<string, HTMLButtonElement>();
  let worker: Worker | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let outputRevision = 0;
  let phase: Stage = "decode";
  stage.value = "decode";

  const narrow = matchMedia("(max-width: 640px)");

  function showFiles(show: boolean) {
    sidebar.hidden = !show;
    toggleFiles.setAttribute("aria-expanded", String(show));
  }

  showFiles(!narrow.matches);
  narrow.addEventListener("change", (event) => showFiles(!event.matches));
  toggleFiles.addEventListener("click", () =>
    showFiles(Boolean(sidebar.hidden)),
  );

  function showAddFile(show: boolean) {
    addFile.hidden = !show;
    newFile.setAttribute("aria-expanded", String(show));
    if (show) pathInput.focus();
    else fileError.textContent = "";
  }

  newFile.addEventListener("click", () => showAddFile(Boolean(addFile.hidden)));
  addFile.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    showAddFile(false);
    newFile.focus();
  });

  function showSettings(show: boolean) {
    advanced.hidden = !show;
    toggleSettings.setAttribute("aria-expanded", String(show));
  }

  toggleSettings.addEventListener("click", () =>
    showSettings(Boolean(advanced.hidden)),
  );
  runSettings.addEventListener("invalid", () => showSettings(true), true);

  function setStatus(message: string, error = false) {
    status.textContent = message;
    status.dataset.error = String(error);
  }

  function updateOptions() {
    const lambda = activePath.endsWith(".lambda");
    for (const option of stage.options) {
      option.disabled =
        !lambda && ["expand", "reduce", "compile"].includes(option.value);
    }
    if (stage.selectedOptions[0]?.disabled) stage.value = "interpret";
    compiler.hidden = compiler.disabled = !lambda;
    const interpreting =
      stage.value === "interpret" || stage.value === "decode";
    interpreter.hidden = interpreter.disabled = !interpreting;
    const decoding = stage.value === "decode";
    element("decode-options").hidden = decode.disabled = !decoding;
    element("precision-options").hidden = precision.disabled =
      !decoding || decode.value.trim() !== "real";
  }

  function renderFiles() {
    const collapsed = new Set(
      Array.from(fileTree.querySelectorAll("details:not([open])"), (folder) =>
        folder.getAttribute("data-path"),
      ),
    );
    const root = document.createDocumentFragment();
    const folders = new Map<string, HTMLUListElement>();
    fileButtons.clear();

    for (const path of [...files.keys()].sort()) {
      const parts = path.split("/");
      const name = parts.pop() ?? path;
      let parent: DocumentFragment | HTMLUListElement = root;
      let folderPath = "";
      for (const part of parts) {
        folderPath += `${part}/`;
        let children = folders.get(folderPath);
        if (!children) {
          const item = document.createElement("li");
          const folder = document.createElement("details");
          const label = document.createElement("summary");
          folder.dataset.path = folderPath;
          folder.open = !collapsed.has(folderPath);
          label.textContent = part;
          label.title = folderPath;
          children = document.createElement("ul");
          folder.append(label, children);
          item.append(folder);
          parent.append(item);
          folders.set(folderPath, children);
        }
        parent = children;
      }

      const item = document.createElement("li");
      const button = document.createElement("button");
      item.className = "file-row";
      button.type = "button";
      button.className = "file-open";
      button.textContent = name;
      button.title = path;
      button.addEventListener("click", () => {
        selectFile(path);
        if (narrow.matches) {
          showFiles(false);
          editor.focus();
        }
      });
      item.append(button);
      parent.append(item);
      fileButtons.set(path, button);
    }
    fileTree.replaceChildren(root);
  }

  function getModel(path: string) {
    const existing = models.get(path);
    if (existing) return existing;
    const model = createSourceModel(path, files.get(path) ?? "");
    model.onDidChangeContent(() => {
      files.set(path, model.getValue());
      languageChanged();
    });
    models.set(path, model);
    return model;
  }

  function selectFile(path: string) {
    if (models.has(activePath)) {
      viewStates.set(activePath, editor.saveViewState());
    }
    fileButtons.get(activePath)?.removeAttribute("aria-current");
    const model = getModel(path);
    editor.setModel(model);
    const viewState = viewStates.get(path);
    if (viewState) editor.restoreViewState(viewState);
    activePath = path;
    const button = fileButtons.get(path);
    button?.setAttribute("aria-current", "true");
    let ancestor = button?.closest("details");
    while (ancestor) {
      ancestor.open = true;
      ancestor = ancestor.parentElement?.closest("details") ?? null;
    }
    activeFile.textContent = path;
    activeFile.title = path;
    removeFile.title = `删除 ${path}`;
    removeFile.setAttribute("aria-label", removeFile.title);
    if (files.size > 1) button?.after(removeFile);
    else removeFile.remove();
    updateOptions();
  }

  const languageChanged = connectLanguageService(
    editor,
    () => files,
    selectFile,
    getModel,
    (message) => {
      element("language-status").textContent = message;
    },
  );
  renderFiles();
  selectFile(activePath);
  stage.addEventListener("change", updateOptions);
  decode.addEventListener("input", updateOptions);

  addFile.addEventListener("submit", (event) => {
    event.preventDefault();
    const path = sessionPath(pathInput.value.trim());
    if (!path) {
      fileError.textContent = "仅支持以 .lambda 或 .ski 结尾的路径。";
      return;
    }
    if (
      Array.from(files.keys()).some(
        (file) =>
          file === path ||
          file.startsWith(`${path}/`) ||
          path.startsWith(`${file}/`),
      )
    ) {
      fileError.textContent = "该文件路径已存在或发生冲突。";
      return;
    }
    files.set(path, "");
    languageChanged();
    pathInput.value = "";
    showAddFile(false);
    if (narrow.matches) showFiles(false);
    renderFiles();
    selectFile(path);
    editor.focus();
  });

  removeFile.addEventListener("click", () => {
    const path = activePath;
    files.delete(path);
    languageChanged();
    const model = models.get(path);
    models.delete(path);
    viewStates.delete(path);
    const next = files.keys().next().value;
    if (next) {
      renderFiles();
      selectFile(next);
      fileButtons.get(next)?.focus();
    }
    model?.dispose();
    fileError.textContent = "";
  });

  function finish(message: string, error = false) {
    worker?.terminate();
    worker = undefined;
    clearTimeout(timer);
    run.disabled = sidebar.inert;
    cancel.hidden = true;
    setStatus(message, error);
  }

  cancel.addEventListener("click", () =>
    finish(`已取消 · ${stageLabels[phase]}`),
  );
  runSettings.addEventListener("submit", (event) => {
    event.preventDefault();
    if (worker || sidebar.inert) return;
    results.open = true;
    outputRevision++;
    output.hidden = true;
    output.textContent = "";
    stepCount.textContent = "";

    const encoder = new TextEncoder();
    let bytes = 0;
    for (const source of files.values()) {
      bytes += encoder.encode(source).byteLength;
    }
    if (bytes > inputLimit) {
      setStatus(`会话源码超过 ${inputLimit / (1024 * 1024)} MiB。`, true);
      return;
    }

    const request: RunRequest = {
      entry: activePath,
      files: Array.from(files),
      stage: stage.value as Stage,
      reduction: element<HTMLSelectElement>("reduction").value,
      natural: element<HTMLSelectElement>("encode-natural").value,
      string: element<HTMLSelectElement>("encode-string").value,
      decode: decode.value.trim(),
      precision: precision.valueAsNumber,
      steps: steps.valueAsNumber,
    };
    phase =
      request.entry.endsWith(".lambda") &&
      (request.stage === "interpret" || request.stage === "decode")
        ? "compile"
        : request.stage;
    setStatus(`正在运行 · ${stageLabels[phase]}`);
    try {
      const active = new Worker(
        new URL("./runtime.worker.ts", import.meta.url),
        { type: "module" },
      );
      worker = active;
      run.disabled = true;
      cancel.hidden = false;
      timer = setTimeout(
        () =>
          finish(
            `运行超过 ${runTimeoutMs / 1000} 秒 · ${stageLabels[phase]}`,
            true,
          ),
        runTimeoutMs,
      );
      active.onmessage = ({ data }: MessageEvent<RunMessage>) => {
        if (worker !== active) return;
        phase = data.stage;
        const label = stageLabels[phase];
        if ("error" in data) {
          output.hidden = false;
          output.textContent = data.error;
          finish(`运行失败 · ${label}`, true);
        } else if ("output" in data) {
          output.hidden = false;
          output.textContent = data.output;
          if (phase !== "decode") {
            const revision = outputRevision;
            const extension =
              phase === "expand" || phase === "reduce" ? "lambda" : "ski";
            void highlightedLines(data.output, extension, false)
              .then((lines) => {
                if (revision === outputRevision)
                  output.innerHTML = lines.join("\n");
              })
              .catch(() => {});
          }
          if (data.steps !== undefined)
            stepCount.textContent = `归约步数 ${data.steps}`;
          finish(`运行完成 · ${label}`);
        } else {
          setStatus(`正在运行 · ${label}`);
        }
      };
      active.onerror = () => {
        if (worker === active)
          finish(`运行环境异常 · ${stageLabels[phase]}`, true);
      };
      active.postMessage({ ...request, wasmBase: sitePath("/playground/") });
    } catch {
      finish(`无法启动运行环境 · ${stageLabels[phase]}`, true);
    }
  });

  async function loadExampleSession(example: string, slug?: string) {
    sidebar.inert =
      run.disabled =
      toggleFiles.disabled =
      loadExample.disabled =
        true;
    editor.updateOptions({ readOnly: true });
    if (!worker) setStatus("正在载入示例");
    try {
      const response = await fetch(sitePath("/playground/examples.json"));
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const entry = `examples/${example}`;
      const imported = exampleSession(entry, await response.json(), slug);
      if (!imported.size) throw new Error("找不到示例文件。");

      finish("示例已载入");
      outputRevision++;
      output.hidden = true;
      output.textContent = "";
      stepCount.textContent = "";
      results.open = false;
      pathInput.value = "";
      showAddFile(false);
      editor.setModel(null);
      for (const model of models.values()) model.dispose();
      models.clear();
      viewStates.clear();
      files = imported;
      languageChanged();
      fileTree.replaceChildren();
      stage.value = "interpret";
      renderFiles();
      selectFile(entry);
    } catch (error) {
      setStatus(
        `示例载入失败 · ${error instanceof Error ? error.message : String(error)}`,
        true,
      );
    } finally {
      sidebar.inert = toggleFiles.disabled = loadExample.disabled = false;
      run.disabled = Boolean(worker);
      editor.updateOptions({ readOnly: false });
    }
  }

  loadExample.addEventListener("change", async () => {
    const entry = loadExample.value;
    const slug = loadExample.selectedOptions[0]?.dataset.example;
    loadExample.value = "";
    if (entry && slug) await loadExampleSession(entry, slug);
  });

  const example = new URLSearchParams(location.search).get("example");
  if (example) await loadExampleSession(example);
  else loadExample.disabled = false;
}
