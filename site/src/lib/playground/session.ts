export type Stage = "expand" | "reduce" | "compile" | "interpret" | "decode";
export interface RunRequest {
  entry: string;
  files: [string, string][];
  stage: Stage;
  reduction: string;
  natural: string;
  string: string;
  decode: string;
  steps: number;
}

export type RunMessage =
  | { stage: Stage }
  | { stage: Stage; output: string; steps?: string }
  | { stage: Stage; error: string };

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
