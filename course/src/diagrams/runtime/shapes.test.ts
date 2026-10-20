import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { between } from './shapes';

describe('between', () => {
  it('moves each number of two values written alike', () => {
    const at = between('M80 491 H642', 'M171 82 H291');
    assert.deepEqual(
      [0, 0.5, 1].map(t => at?.(t)),
      ['M80 491 H642', 'M125.5 286.5 H466.5', 'M171 82 H291']
    );
  });

  it('moves the numbers of a style, leaving the rest as written', () => {
    const at = between(
      'fill-opacity: 0; stroke-dasharray: 8 6',
      'fill-opacity: 1; stroke-dasharray: 8 0'
    );
    assert.equal(at?.(0.5), 'fill-opacity: 0.5; stroke-dasharray: 8 3');
  });

  it('ends exactly on the second value, unrounded', () => {
    assert.equal(between('0', '0.333333')?.(1), '0.333333');
  });

  it('is null for two values not written alike', () => {
    assert.equal(between('M0 0 H10', 'M0 0 V10'), null);
  });
});
