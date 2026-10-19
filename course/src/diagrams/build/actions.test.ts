import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { copyOf, diagram, during, runs, START, step } from '.';
import { generate } from './generate';

describe('runs', () => {
  it('makes a stretch of each run of consecutive steps', () => {
    assert.deepEqual(runs([1, 2, 5], 7), [
      { from: 1, to: 3 },
      { from: 5, to: 6 }
    ]);
  });

  it('goes on to the end from a stretch reaching the last step', () => {
    assert.deepEqual(runs([4, 5], 6), [{ from: 4 }]);
  });

  it('takes the steps in any order, and each once', () => {
    assert.deepEqual(runs([2, 1, 1], 5), [{ from: 1, to: 3 }]);
  });

  it('starts before the first step from the start', () => {
    assert.deepEqual(runs([START, 0], 3), [{ from: START, to: 1 }]);
  });

  it('is none without steps', () => {
    assert.deepEqual(runs([], 3), []);
  });
});

describe('during', () => {
  it('shows a copy from its first step until the next, or from the start, marking each step it ends at once', () => {
    const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" class="diagram">' +
      '<title>A lamp</title><style id="diagram-styles"/><defs id="diagram-defs"/>' +
      '<g id="glow" class="transient"><circle id="halo" r="3"/></g>' +
      '</svg>';
    const glows =
      (...runsOf: { from: number; to?: number }[]) =>
      (builder: Parameters<typeof during>[0]) => {
        const glow = builder.element('glow');
        for (const run of runsOf) {
          const copy = copyOf(glow);
          glow.parentNode?.appendChild(copy);
          during(builder, copy, run);
        }
      };

    assert.equal(
      generate({
        name: 'lamp',
        svg,
        definition: diagram({
          captions: { rest: 'A lamp.', start: 'A lamp, dim.' },
          start: [glows({ from: START, to: 1 })],
          steps: [
            step('It flickers.', glows({ from: 0, to: 1 })),
            step('It glows.', glows({ from: 1 }))
          ]
        }),
        motion: ''
      }),
      [
        '<!-- Generated from diagrams/lamp.svg and lamp.ts by "npm run diagrams": edit those instead. -->',
        '<div class="diagram-figure" data-diagram="lamp">',
        '<div class="diagram-canvas">',
        '<svg xmlns="http://www.w3.org/2000/svg" class="diagram" role="img" aria-labelledby="diagram-lamp-title">' +
          '<title id="diagram-lamp-title">A lamp</title>' +
          '<style id="diagram-lamp-diagram-styles"/><style class="diagram-motion"></style>' +
          '<defs id="diagram-lamp-diagram-defs"/>' +
          '<g class="fragment teardown" data-fragment-index="1"/>' +
          '<g id="diagram-lamp-glow" class="transient"><circle id="diagram-lamp-halo" r="3"/></g>' +
          '<g class="detail" data-gone-from="1"><circle r="3"/></g>' +
          '<g class="fragment transient" data-fragment-index="0" data-gone-from="1"><circle r="3"/></g>' +
          '<g class="fragment transient" data-fragment-index="1"><circle r="3"/></g>' +
          '</svg>',
        '</div>',
        '<template class="diagram-captions">' +
          '<p data-caption="rest">A lamp.</p>' +
          '<p data-caption="0">A lamp, dim.</p>' +
          '<p data-caption="1">It flickers.</p>' +
          '<p data-caption="2">It glows.</p>' +
          '</template>',
        '</div>',
        ''
      ].join('\n')
    );
  });
});
