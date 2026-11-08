const assert = require('node:assert/strict');
const test = require('node:test');
const { tokenizeFixture: tokenizeFixtureFor, scopesAt, assertScope } = require('./utils.cjs');
const tokenizeFixture = tokenizeFixtureFor('source.ski-graph');

test('highlights SKI node definitions, references, combinators, and comments', async () => {
  const fixture = await tokenizeFixture('highlights.ski');

  assertScope(fixture, 0, '#0', 'entity.name.label.node.ski-graph');
  assertScope(fixture, 0, '=', 'keyword.operator.assignment.ski-graph');
  assertScope(fixture, 0, '#1', 'variable.other.reference.ski-graph');
  assertScope(fixture, 0, '#2', 'variable.other.reference.ski-graph');
  assertScope(fixture, 0, ';', 'punctuation.terminator.ski-graph');

  for (const [line, combinator] of [[1, 'S'], [2, 'K'], [3, 'I']]) {
    assertScope(fixture, line, combinator, 'constant.language.combinator.ski-graph');
  }

  assertScope(fixture, 4, '-- #4 = S;', 'comment.line.double-dash.ski-graph');
  assertScope(fixture, 4, '#4', 'comment.line.double-dash.ski-graph');
  assert(!scopesAt(fixture, 4, '#4').includes('entity.name.label.node.ski-graph'));
});
