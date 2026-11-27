import { command } from "./runtime";

export type SourceRange = [number, number, number, number];

export interface LanguageResults {
  diagnostics: [SourceRange, string][];
  tokens: [SourceRange, number][];
  symbols: [string, SourceRange][];
  completion: [string, number, string | null, string | null, SourceRange][];
  hover: [string, SourceRange] | null;
  definition: [string, SourceRange] | null;
  references: SourceRange[];
  signature: [string, string[], number] | null;
  prepareRename: SourceRange | null;
  rename: [string, SourceRange[]] | null;
}

export interface LanguageRequest {
  operation: keyof LanguageResults;
  path: string;
  source: string;
  files: [string, string][];
  args: string[];
}

export async function analyzeSource(
  module: WebAssembly.Module,
  { operation, path, source, files, args }: LanguageRequest,
): Promise<LanguageResults[keyof LanguageResults]> {
  const { output } = await command(
    module,
    ["language-service", operation, path, ...args],
    files,
    source,
  );
  return JSON.parse(output);
}
