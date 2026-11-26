import assert from "node:assert/strict";
import { highlightedLines } from "../src/lib/highlight.ts";

Deno.test("playground highlights Lambda and SKI with distinct token colors", async () => {
  for (
    const [source, extension, tokens] of [
      ["@! ADD 2;", "lambda", ["@!", "ADD", "2"]],
      ["#0 = S; -- root", "ski", ["=", "S", "-- root"]],
    ] as const
  ) {
    const [line] = await highlightedLines(source, extension, false);
    const styles = Array.from(
      line.matchAll(/<span style="([^"]+)">([^<]*)<\/span>/g),
    );
    const colors = tokens.map((token) =>
      styles.find(([, , text]) => text === token)?.[1]
    );
    assert.ok(
      colors.every((style) =>
        style?.includes("--token-light:") && style.includes("--token-dark:")
      ),
    );
    assert.equal(new Set(colors).size, tokens.length);
  }
});

Deno.test("live highlighting preserves blank lines and escapes source markup", async () => {
  const lines = await highlightedLines('\n@< "<tag>&";\n\n', "lambda", false);
  assert.equal(lines.length, 4);
  assert.equal(lines[0], "");
  assert.deepEqual(lines.slice(2), ["", ""]);
  assert.ok(lines[1].includes("&quot;&lt;tag&gt;&amp;&quot;"));
});
