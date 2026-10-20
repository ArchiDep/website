import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { becomes, diagram, step, type Becoming } from '.';
import { generate } from './generate';
import { parseSvg } from './svg';

const HEAD =
  '<svg xmlns="http://www.w3.org/2000/svg" class="diagram">' +
  '<title>A lamp</title><style id="diagram-styles"/><defs id="diagram-defs"/>';

const LAMP =
  HEAD +
  '<rect id="lamp" x="0" y="0" width="10" height="10"/>' +
  '<g id="base"><rect x="0" y="20" width="10" height="2"/></g>' +
  '<text id="glow">On</text>' +
  '</svg>';

// The same lamp moved and widened, its base moved, with a shade instead of a
// glow, and a part only its fully drawn diagram shows.
const MOVED = parseSvg(
  HEAD +
    '<rect id="lamp" x="30" y="0" width="20" height="10"/>' +
    '<g id="base"><rect x="35" y="25" width="10" height="2"/></g>' +
    '<circle id="shade" r="5"/>' +
    '<circle class="at-rest" r="9"/>' +
    '</svg>',
  'moved.svg'
);

function generated(becoming: Becoming, svg = LAMP): string {
  return generate({
    name: 'lamp',
    svg,
    definition: diagram({
      captions: { rest: 'A lamp.', start: 'A lamp, here.' },
      steps: [step('It moves.', becomes(MOVED, becoming))]
    }),
    motion: ''
  });
}

describe('becomes', () => {
  it('moves the parts both drawings have, takes the others away and brings the others in, once the rest is in place', () => {
    assert.equal(
      generated({
        moved: ['lamp', 'base'],
        leaving: ['glow'],
        arriving: ['shade']
      }),
      [
        '<!-- Generated from diagrams/lamp.svg and lamp.ts by "npm run diagrams": edit those instead. -->',
        '<div class="diagram-figure" data-diagram="lamp">',
        '<div class="diagram-canvas">',
        '<svg xmlns="http://www.w3.org/2000/svg" class="diagram" role="img" aria-labelledby="diagram-lamp-title">' +
          '<title id="diagram-lamp-title">A lamp</title>' +
          '<style id="diagram-lamp-diagram-styles"/><style class="diagram-motion"></style>' +
          '<defs id="diagram-lamp-diagram-defs"/>' +
          '<g class="fragment teardown" data-fragment-index="0"/>' +
          '<g class="fragment reshape" data-fragment-index="0" style="--delay: 0.3s; --duration: 0.9s"/>' +
          '<rect id="diagram-lamp-lamp" x="0" y="0" width="10" height="10" data-reshaped-x="30" data-reshaped-width="20"/>' +
          '<g id="diagram-lamp-base" transform="translate(0 0)" data-reshaped-transform="translate(35 5)">' +
          '<rect x="0" y="20" width="10" height="2"/>' +
          '</g>' +
          '<text id="diagram-lamp-glow" data-gone-from="0">On</text>' +
          '<circle r="5" class="fragment transient arrive" data-fragment-index="0" style="--delay: 1.2s"/>' +
          '</svg>',
        '</div>',
        '<template class="diagram-captions">' +
          '<p data-caption="rest">A lamp.</p>' +
          '<p data-caption="0">A lamp, here.</p>' +
          '<p data-caption="1">It moves.</p>' +
          '</template>',
        '</div>',
        ''
      ].join('\n')
    );
  });

  it('fails on a part of this drawing left out, which would vanish when cutting to the other', () => {
    assert.throws(
      () =>
        generated({
          moved: ['lamp', 'base'],
          leaving: [],
          arriving: ['shade']
        }),
      new Error(
        'lamp.svg: a <text> "glow" shown at its end is neither moved, leaving nor arriving'
      )
    );
  });

  it('fails on a part of the other drawing left out, which would appear when cutting to it', () => {
    assert.throws(
      () =>
        generated({ moved: ['lamp', 'base'], leaving: ['glow'], arriving: [] }),
      new Error(
        'lamp.svg: a <circle> "shade" shown as the other starts is neither moved, leaving nor arriving'
      )
    );
  });

  it('fails on a part drawn as two different shapes', () => {
    assert.throws(
      () =>
        generated(
          { moved: ['lamp', 'base'], leaving: [], arriving: ['shade'] },
          HEAD +
            '<circle id="lamp" r="10"/>' +
            '<g id="base"><rect x="0" y="20" width="10" height="2"/></g>' +
            '</svg>'
        ),
      new Error(
        '"lamp" is a <circle> here and a <rect> in the drawing it becomes'
      )
    );
  });
});
