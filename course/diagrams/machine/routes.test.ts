import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';

import { DOMParser } from '@xmldom/xmldom';

import { CELLS } from './routes';

describe('CELLS', () => {
  it('is where the drawing draws each cell', () => {
    const doc = new DOMParser().parseFromString(
      readFileSync(path.join(import.meta.dirname, '..', 'machine.svg'), 'utf8'),
      'image/svg+xml'
    );
    const boxes = Array.from({ length: 16 }, (_, cell) => {
      const box = Array.from(
        doc.getElementById(`cell-${cell}`)?.getElementsByTagName('rect') ?? []
      ).find(rect => rect.getAttribute('class') === 'cell');
      return ['x', 'y', 'height'].map(attribute =>
        Number(box?.getAttribute(attribute))
      );
    });

    assert.deepEqual(
      boxes,
      Array.from({ length: 16 }, (_, cell) => [
        CELLS.x,
        CELLS.y + cell * CELLS.pitch,
        CELLS.height
      ])
    );
  });
});
