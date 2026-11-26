export const runTimeoutMs = 10_000;
export const inputLimit = 1024 * 1024;
export const outputLimit = 2 * 1024 * 1024;

export type Stage = "expand" | "reduce" | "compile" | "interpret" | "decode";
export interface RunRequest {
  entry: string;
  files: [string, string][];
  stage: Stage;
  reduction: string;
  natural: string;
  string: string;
  decode: string;
  precision: number;
  steps: number;
}

export type RunMessage =
  | { stage: Stage }
  | { stage: Stage; output: string; steps?: string }
  | { stage: Stage; error: string };

export const stageLabels: Record<Stage, string> = {
  expand: "展开",
  reduce: "归约",
  compile: "编译",
  interpret: "解释",
  decode: "解码",
};

export function sessionPath(input: string) {
  if (
    !/^[^/\\:]+(?:\/[^/\\:]+)*\.(?:lambda|ski)$/.test(input) ||
    Array.from(input).some((character) => character.charCodeAt(0) < 32)
  ) {
    return undefined;
  }
  const parts: string[] = [];
  for (const part of input.split("/")) {
    if (part === "..") {
      if (!parts.pop()) return undefined;
    } else if (part !== ".") {
      parts.push(part);
    }
  }
  return parts.join("/");
}

export function exampleSession(entry: string, sources: Record<string, string>) {
  const files = new Map<string, string>();
  function visit(file: string) {
    if (!Object.hasOwn(sources, file) || files.has(file)) return;
    const source = sources[file];
    files.set(file, source);
    if (!file.endsWith(".lambda")) return;

    // Skip comments and string literals that are outside import directives.
    const tokens =
      /#[^\n]*|@<\s*(?:#[^\n]*\n\s*)*("(?:[^"\\]|\\.)*")|"(?:[^"\\]|\\.)*"/g;
    for (const [, literal] of source.matchAll(tokens)) {
      if (!literal) continue;
      const relative = literal
        .slice(1, -1)
        .replace(/\\([nt"\\])/g, (_, character) =>
          character === "n" ? "\n" : character === "t" ? "\t" : character,
        );
      const folder = file.slice(0, file.lastIndexOf("/") + 1);
      const target = sessionPath(
        relative.startsWith("/") ? relative.slice(1) : folder + relative,
      );
      if (target) visit(target);
    }
  }
  visit(entry);
  return files;
}
