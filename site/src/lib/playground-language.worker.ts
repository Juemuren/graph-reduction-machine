import {
  analyzeSource,
  type LanguageRequest,
} from "./playground-language-protocol";

let module: Promise<WebAssembly.Module> | undefined;

self.addEventListener(
  "message",
  async ({ data }: MessageEvent<LanguageRequest & { wasmBase: string }>) => {
    try {
      module ??= fetch(`${data.wasmBase}language-service.wasm`).then(
        async (response) => {
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          return WebAssembly.compile(await response.arrayBuffer());
        },
      );
      self.postMessage({ result: await analyzeSource(await module, data) });
    } catch (error) {
      self.postMessage({ error: String(error) });
    }
  },
);
