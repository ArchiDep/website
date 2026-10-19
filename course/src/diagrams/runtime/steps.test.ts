import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { fadedAt, reachedIndex } from './steps';

describe('reachedIndex', () => {
  it('is the highest index of the steps shown', () => {
    assert.equal(
      reachedIndex([
        { index: 0, visible: true },
        { index: 2, visible: true },
        { index: 1, visible: true },
        { index: 3, visible: false }
      ]),
      2
    );
  });

  it('is -1 when no step is shown', () => {
    assert.equal(reachedIndex([{ index: 0, visible: false }]), -1);
  });
});

describe('fadedAt', () => {
  it('is true at a step listed', () => {
    assert.equal(fadedAt('1 4 12', 4), true);
  });

  it('is false at a step not listed', () => {
    assert.equal(fadedAt('1 4 12', 2), false);
  });

  it('is false when no step is reached', () => {
    assert.equal(fadedAt('0', -1), false);
  });
});
