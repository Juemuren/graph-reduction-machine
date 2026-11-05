import {
  type CompletionItem,
  CompletionItemKind,
  createConnection,
  type Hover,
  MarkupKind,
  ProposedFeatures,
  TextDocumentSyncKind,
  TextDocuments,
} from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { completeCoreLambda, hoverCoreLambda } from './core-lambda';

const connection = createConnection(ProposedFeatures.all);
const documents = new TextDocuments(TextDocument);

connection.onInitialize(() => ({
  capabilities: {
    textDocumentSync: TextDocumentSyncKind.Incremental,
    completionProvider: { triggerCharacters: ['#'] },
    hoverProvider: true,
  },
}));

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

connection.onCompletion(({ textDocument, position }): CompletionItem[] => {
  const document = documents.get(textDocument.uri);
  if (!document) return [];

  if (document.languageId === 'core-lambda') return completeCoreLambda(document, position);
  if (document.languageId !== 'ski-graph') return [];

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
});

connection.onHover(({ textDocument, position }): Hover | null => {
  const document = documents.get(textDocument.uri);
  if (!document) return null;

  if (document.languageId === 'core-lambda') return hoverCoreLambda(document, position);
  if (document.languageId !== 'ski-graph') return null;

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
});

documents.listen(connection);
connection.listen();
