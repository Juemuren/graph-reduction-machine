import {
  ConsoleStdout,
  Directory,
  File,
  type Inode,
  OpenFile,
  PreopenDirectory,
  WASI,
} from "@bjorn3/browser_wasi_shim";
import { outputLimit } from "../../config";
import type { RunMessage, RunRequest, Stage } from "./session";

type Program = "lambda-compiler" | "ski-interpreter";
type LoadProgram = (name: Program) => Promise<WebAssembly.Module>;
const encoder = new TextEncoder();

function virtualFiles(files: [string, string][]) {
  const root = new Map<string, Inode>();
  for (const [file, source] of files) {
    const segments = file.split("/");
    const name = segments.pop() as string;
    let folder = root;
    for (const segment of segments) {
      let child = folder.get(segment);
      if (!child) {
        child = new Directory(new Map());
        folder.set(segment, child);
      }
      if (!(child instanceof Directory))
        throw new Error(`文件路径冲突：${file}`);
      folder = child.contents;
    }
    if (folder.has(name)) throw new Error(`文件路径冲突：${file}`);
    folder.set(name, new File(encoder.encode(source), { readonly: true }));
  }
  return root;
}

function capture() {
  const decoder = new TextDecoder();
  let output = "";
  let bytes = 0;
  const fd = new ConsoleStdout((chunk) => {
    bytes += chunk.byteLength;
    if (bytes > outputLimit)
      throw new Error(`输出超过 ${outputLimit / (1024 * 1024)} MiB。`);
    output += decoder.decode(chunk, { stream: true });
  });
  return { fd, read: () => output + decoder.decode() };
}

export async function command(
  module: WebAssembly.Module,
  args: string[],
  files: [string, string][],
  input: string,
) {
  const stdout = capture();
  const stderr = capture();
  const wasi = new WASI(
    args,
    ["LANG=C.UTF-8"],
    [
      new OpenFile(new File(encoder.encode(input))),
      stdout.fd,
      stderr.fd,
      new PreopenDirectory("/", virtualFiles(files)),
    ],
  );
  const instance = await WebAssembly.instantiate(module, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });
  const { memory, _start } = instance.exports;
  if (!(memory instanceof WebAssembly.Memory) || typeof _start !== "function") {
    throw new Error("WebAssembly 命令缺少所需的导出。");
  }

  let code: number;
  try {
    code = wasi.start({ exports: { memory, _start: () => _start() } });
  } catch (error) {
    const diagnostic = stderr.read().trim();
    if (diagnostic) throw new Error(diagnostic);
    throw error;
  }

  const diagnostic = stderr.read().trim();
  if (code !== 0) throw new Error(diagnostic || `运行失败（退出码 ${code}）。`);
  return {
    output: stdout.read().replace(/\n$/, ""),
    steps: /^steps: (\d+)$/m.exec(diagnostic)?.[1],
  };
}

export async function runPlayground(
  request: RunRequest,
  load: LoadProgram,
  send: (message: RunMessage) => void,
) {
  const { entry, files, stage } = request;
  const compileOnly =
    stage === "expand" || stage === "reduce" || stage === "compile";
  let phase: Stage = stage;
  try {
    let graph = new Map(files).get(entry);
    if (graph === undefined) throw new Error("找不到当前文件。");

    if (entry.endsWith(".lambda")) {
      phase = compileOnly ? stage : "compile";
      send({ stage: phase });
      const args = [
        "lambda-compiler",
        `--stop-after=${phase}`,
        `--reduce=${request.reduction}`,
        `--encode-natural=${request.natural}`,
        `--encode-string=${request.string}`,
      ];
      const compiled = await command(
        await load("lambda-compiler"),
        [...args, `/${entry}`],
        files,
        "",
      );
      graph = compiled.output;
      if (compileOnly) {
        send({ stage: phase, output: graph });
        return;
      }
    } else if (compileOnly) {
      throw new Error("此阶段需要核心 λ 源码。");
    }

    phase = stage;
    send({ stage: phase });
    const args = [
      "ski-interpreter",
      "--show-steps",
      `--max-steps=${request.steps}`,
    ];
    if (stage === "decode") {
      args.push(`--decode=${request.decode}`);
    }
    const result = await command(
      await load("ski-interpreter"),
      args,
      [],
      graph,
    );
    send({ stage: phase, ...result });
  } catch (error) {
    const diagnostic = error instanceof Error ? error.message : String(error);
    const message =
      /heap exhausted|out of memory|memory allocation|memory\.grow|grow memory|stack (?:space )?overflow/i.test(
        diagnostic,
      )
        ? `运行超出内存或栈上限。\n${diagnostic}`
        : diagnostic;
    send({ stage: phase, error: message });
  }
}
