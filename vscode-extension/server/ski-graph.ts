import {
  type CompletionItem,
  CompletionItemKind,
  type Hover,
  MarkupKind,
  type Position,
} from 'vscode-languageserver/node';
import type { TextDocument } from 'vscode-languageserver-textdocument';

function linesOf(document: TextDocument): string[] {
  return document.getText().split(/\r\n|\r|\n/);
}

function definitions(lines: string[]): Map<string, string> {
  const nodes = new Map<string, string>();
  for (const line of lines) {
    const code = line.split('--', 1)[0].trim();
    const match = /^(#[0-9]+)\s*=\s*(#[0-9]+\s+#[0-9]+|[SKI])\s*;?$/.exec(code);
    if (match && !nodes.has(match[1])) {
      nodes.set(match[1], `${match[1]} = ${match[2].replace(/\s+/g, ' ')}`);
    }
  }
  return nodes;
}

function codeBeforeComment(line: string): string {
  const comment = line.indexOf('--');
  return comment < 0 ? line : line.slice(0, comment);
}

export function completeSki(document: TextDocument, position: Position): CompletionItem[] {
  const lines = linesOf(document);
  const line = codeBeforeComment(lines[position.line] ?? '');
  if (position.character > line.length) return [];
  const before = line.slice(0, position.character);
  const prefix = /#[0-9]*$/.exec(before);
  if (!prefix) return [];

  const suffix = /^[0-9]*/.exec(line.slice(position.character))?.[0] ?? '';
  const range = {
    start: { line: position.line, character: position.character - prefix[0].length },
    end: { line: position.line, character: position.character + suffix.length },
  };
  return [...definitions(lines).entries()].map(([label, definition]) => ({
    label,
    kind: CompletionItemKind.Reference,
    detail: definition,
    textEdit: { range, newText: label },
  }));
}

export function hoverSki(document: TextDocument, position: Position): Hover | null {
  const lines = linesOf(document);
  const line = codeBeforeComment(lines[position.line] ?? '');
  const nodes = definitions(lines);
  for (const match of line.matchAll(/#[0-9]+/g)) {
    const start = match.index;
    const end = start + match[0].length;
    if (start <= position.character && position.character < end) {
      const definition = nodes.get(match[0]);
      if (!definition) return null;
      return {
        contents: { kind: MarkupKind.Markdown, value: `\`\`\`ski-graph\n${definition}\n\`\`\`` },
        range: {
          start: { line: position.line, character: start },
          end: { line: position.line, character: end },
        },
      };
    }
  }
  return null;
}
