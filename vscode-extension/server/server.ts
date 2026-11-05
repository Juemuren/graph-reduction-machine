import {
  createConnection,
  ProposedFeatures,
  TextDocumentSyncKind,
  TextDocuments,
} from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { completeCoreLambda, hoverCoreLambda } from './core-lambda';
import { completeSki, hoverSki } from './ski-graph';

const connection = createConnection(ProposedFeatures.all);
const documents = new TextDocuments(TextDocument);

connection.onInitialize(() => ({
  capabilities: {
    textDocumentSync: TextDocumentSyncKind.Incremental,
    completionProvider: { triggerCharacters: ['#'] },
    hoverProvider: true,
  },
}));

connection.onCompletion(({ textDocument, position }) => {
  const document = documents.get(textDocument.uri);
  if (!document) return [];

  if (document.languageId === 'core-lambda') return completeCoreLambda(document, position);
  if (document.languageId === 'ski-graph') return completeSki(document, position);
  return [];
});

connection.onHover(({ textDocument, position }) => {
  const document = documents.get(textDocument.uri);
  if (!document) return null;

  if (document.languageId === 'core-lambda') return hoverCoreLambda(document, position);
  if (document.languageId === 'ski-graph') return hoverSki(document, position);
  return null;
});

documents.listen(connection);
connection.listen();
