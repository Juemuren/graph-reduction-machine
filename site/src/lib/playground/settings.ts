import { stageLabels } from "../../config";
import { validDecode } from "./decode-type";
import type { RunRequest, Stage } from "./session";

type Settings = Omit<RunRequest, "entry" | "files">;

export const reductions = ["none", "beta", "eta", "both"];
export const encodings = ["church", "scott", "binary"];
export const stringEncodings = ["church", "scott"].flatMap((list) =>
  encodings.map((natural) => `${list}<${natural}>`),
);
export const maxRunInteger = 2147483647;

export function supportsStage(path: string, stage: string) {
  return (
    path.endsWith(".lambda") || stage === "interpret" || stage === "decode"
  );
}

export function runOptions(path: string, stage: string, decode: string) {
  const compiler = path.endsWith(".lambda");
  const interpreter = stage === "interpret" || stage === "decode";
  return {
    compiler,
    reduction: compiler && stage !== "expand",
    interpreter,
    decode: stage === "decode",
    precision: stage === "decode" && decode === "real",
  };
}

export function parsePreset(
  path: string,
  value: unknown,
): Pick<Settings, "stage"> & Partial<Settings> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("预设必须是对象");
  }
  const fields = value as Record<string, unknown>;
  for (const key of Object.keys(fields)) {
    if (
      ![
        "stage",
        "reduction",
        "natural",
        "string",
        "decode",
        "precision",
        "steps",
      ].includes(key)
    ) {
      throw new Error(`未知字段 ${key}`);
    }
  }

  function required<T>(
    key: keyof Settings,
    valid: (item: unknown) => item is T,
  ): T {
    if (!Object.hasOwn(fields, key)) throw new Error(`缺少字段 ${key}`);
    const item = fields[key];
    if (!valid(item)) throw new Error(`字段 ${key} 的值无效`);
    return item;
  }

  function choice(key: keyof Settings, values: string[]) {
    return required(
      key,
      (item): item is string =>
        typeof item === "string" && values.includes(item),
    );
  }

  function integer(key: "steps" | "precision") {
    return required(
      key,
      (item): item is number =>
        typeof item === "number" &&
        Number.isInteger(item) &&
        item >= 0 &&
        item <= maxRunInteger,
    );
  }

  const stage = choice("stage", Object.keys(stageLabels)) as Stage;
  if (!supportsStage(path, stage)) throw new Error("当前文件不支持该运行阶段");
  const options = runOptions(path, stage, "");
  const preset: Pick<Settings, "stage"> & Partial<Settings> = { stage };
  if (options.reduction) preset.reduction = choice("reduction", reductions);
  if (options.compiler) {
    preset.natural = choice("natural", encodings);
    preset.string = choice("string", stringEncodings);
  }
  if (options.interpreter) preset.steps = integer("steps");
  if (options.decode) {
    preset.decode = required(
      "decode",
      (item): item is string =>
        typeof item === "string" && validDecode(item.trim()),
    ).trim();
    if (runOptions(path, stage, preset.decode).precision) {
      preset.precision = integer("precision");
    }
  }
  return preset;
}
