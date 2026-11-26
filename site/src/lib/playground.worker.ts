import type { RunRequest } from "./playground";
import { runPlayground } from "./playground-runtime";

self.addEventListener(
  "message",
  (event: MessageEvent<RunRequest & { wasmBase: string }>) => {
    const { wasmBase, ...request } = event.data;
    void runPlayground(
      request,
      async (program) => {
        const response = await fetch(`${wasmBase}${program}.wasm`);
        if (!response.ok)
          throw new Error("无法加载 WebAssembly。请确认演练运行时已构建。");
        return WebAssembly.compile(await response.arrayBuffer());
      },
      (message) => self.postMessage(message),
    );
  },
);
