import { inputLimit, runTimeoutMs, stageLabels } from "../config";
import {
  exampleSession,
  type RunMessage,
  type RunRequest,
  type Stage,
  sessionPath,
} from "./playground";
import { sitePath } from "./urls";

export async function startPlayground() {
  const element = <T extends HTMLElement>(id: string) =>
    document.getElementById(id) as T;
  const editor = element<HTMLTextAreaElement>("source");
  const sourceHighlight = element("source-highlight");
  const sourceEditor = editor.closest<HTMLElement>(".source-editor");
  const highlighter = import("./highlight");
  const filesSelect = element<HTMLSelectElement>("files");
  const addFile = element<HTMLFormElement>("add-file");
  const pathInput = element<HTMLInputElement>("file-path");
  const fileError = element("file-error");
  const removeFile = element<HTMLButtonElement>("remove-file");
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
  let worker: Worker | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let outputRevision = 0;
  let phase: Stage = "decode";
  stage.value = "decode";

  function setStatus(message: string, error = false) {
    status.textContent = message;
    status.dataset.error = String(error);
  }

  function updateOptions() {
    const lambda = filesSelect.value.endsWith(".lambda");
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

  function syncSourceScroll() {
    sourceHighlight.scrollTop = editor.scrollTop;
    sourceHighlight.scrollLeft = editor.scrollLeft;
  }

  function sizeSourceHighlight() {
    sourceHighlight.style.width = `${editor.clientWidth}px`;
    sourceHighlight.style.height = `${editor.clientHeight}px`;
    syncSourceScroll();
  }

  let sourceRevision = 0;
  async function highlightSource() {
    const revision = ++sourceRevision;
    const source = editor.value;
    const extension = filesSelect.value.endsWith(".ski") ? "ski" : "lambda";
    sourceEditor?.removeAttribute("data-highlighted");
    if (source.length > inputLimit) return;

    try {
      const { highlightedLines } = await highlighter;
      if (revision !== sourceRevision) return;
      const lines = await highlightedLines(source, extension, false);
      if (revision !== sourceRevision) return;
      sourceHighlight.innerHTML = `${lines.join("\n")}\n`;
      sizeSourceHighlight();
      sourceEditor?.setAttribute("data-highlighted", "");
    } catch {
      // Keep the native textarea readable if highlighting fails.
    }
  }

  editor.addEventListener("scroll", syncSourceScroll);
  new ResizeObserver(sizeSourceHighlight).observe(editor);

  function selectFile(path: string) {
    filesSelect.replaceChildren(
      ...Array.from(files.keys(), (file) => new Option(file, file)),
    );
    filesSelect.value = path;
    editor.value = files.get(path) ?? "";
    void highlightSource();
    removeFile.disabled = files.size < 2;
    updateOptions();
  }

  selectFile("main.lambda");
  editor.addEventListener("input", () => {
    files.set(filesSelect.value, editor.value);
    void highlightSource();
  });
  filesSelect.addEventListener("change", () => selectFile(filesSelect.value));
  stage.addEventListener("change", updateOptions);
  decode.addEventListener("input", updateOptions);

  addFile.addEventListener("submit", (event) => {
    event.preventDefault();
    const path = sessionPath(pathInput.value.trim());
    if (!path) {
      fileError.textContent = "请输入会话内以 .lambda 或 .ski 结尾的相对路径。";
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
    pathInput.value = "";
    fileError.textContent = "";
    selectFile(path);
    editor.focus();
  });

  removeFile.addEventListener("click", () => {
    files.delete(filesSelect.value);
    const next = files.keys().next().value;
    if (next) selectFile(next);
    fileError.textContent = "";
  });

  function finish(message: string, error = false) {
    worker?.terminate();
    worker = undefined;
    clearTimeout(timer);
    run.disabled = false;
    cancel.disabled = true;
    setStatus(message, error);
  }

  cancel.addEventListener("click", () =>
    finish(`已取消 · ${stageLabels[phase]}`),
  );
  element<HTMLFormElement>("run-settings").addEventListener(
    "submit",
    (event) => {
      event.preventDefault();
      if (worker) return;
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
        entry: filesSelect.value,
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
          new URL("./playground.worker.ts", import.meta.url),
          { type: "module" },
        );
        worker = active;
        run.disabled = true;
        cancel.disabled = false;
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
              void highlighter
                .then(({ highlightedLines }) =>
                  highlightedLines(data.output, extension, false),
                )
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
    },
  );

  const example = new URLSearchParams(location.search).get("example");
  if (!example) return;
  const session = element<HTMLFieldSetElement>("session");
  session.disabled = run.disabled = true;
  setStatus("正在载入示例");
  try {
    const response = await fetch(sitePath("/playground/examples.json"));
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const entry = `examples/${example}`;
    const imported = exampleSession(entry, await response.json());
    if (!imported.size) throw new Error("找不到示例文件。");
    files = imported;
    stage.value = "interpret";
    selectFile(entry);
    setStatus("示例已载入");
  } catch (error) {
    setStatus(
      `示例载入失败 · ${error instanceof Error ? error.message : String(error)}`,
      true,
    );
  } finally {
    session.disabled = run.disabled = false;
  }
}
