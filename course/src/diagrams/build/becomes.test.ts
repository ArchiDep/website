import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { becoming, diagram, step, type Step } from '.';
import { generate } from './generate';
import { parseSvg } from './svg';

const HEAD =
  '<svg xmlns="http://www.w3.org/2000/svg" class="diagram">' +
  '<title>A lamp</title><style id="diagram-styles"/><defs id="diagram-defs"/>';

const LAMP =
  HEAD +
  '<rect id="lamp" x="0" y="0" width="10" height="10"/>' +
  '<g id="base"><rect x="0" y="20" width="10" height="2"/></g>' +
  '<text id="glow" x="0" y="5">On</text>' +
  '</svg>';

// The same lamp moved and widened, its base moved, with a shadow under it and
// a shade instead of a glow, and a part only its fully drawn diagram shows.
const MOVED =
  HEAD +
  '<circle id="shadow" r="20"/>' +
  '<rect id="lamp" x="30" y="0" width="20" height="10"/>' +
  '<g id="base"><rect x="35" y="25" width="10" height="2"/></g>' +
  '<circle id="shade" r="5"/>' +
  '<circle class="at-rest" r="9"/>' +
  '</svg>';

function generated(
  steps: (moved: ReturnType<typeof becoming>) => Step[],
  svg = LAMP
): string {
  return generate({
    name: 'lamp',
    svg,
    definition: diagram({
      captions: { rest: 'A lamp.', start: 'A lamp, here.' },
      steps: steps(becoming(parseSvg(MOVED, 'moved.svg')))
    }),
    motion: ''
  });
}

describe('becoming', () => {
  it('changes parts step by step, takes the others away and brings the others in, once the rest is in place', () => {
    assert.equal(
      generated(moved => [
        step(
          'It dims and widens, unseen.',
          moved.leaving('glow'),
          moved.reshaped({ lamp: { width: '20' } }, { unseen: ['lamp'] })
        ),
        step(
          'It moves, in the shadow.',
          moved.into('lamp', 'base'),
          moved.arriving(['shade']),
          moved.arriving(['shadow'], { under: 'lamp' })
        )
      ]),
      [
        '<!-- Generated from diagrams/lamp.svg and lamp.ts by "npm run diagrams": edit those instead. -->',
        '<div class="diagram-figure" data-diagram="lamp">',
        '<div class="diagram-canvas">',
        '<svg xmlns="http://www.w3.org/2000/svg" class="diagram" role="img" aria-labelledby="diagram-lamp-title">' +
          '<title id="diagram-lamp-title">A lamp</title>' +
          '<style id="diagram-lamp-diagram-styles"/><style class="diagram-motion"></style>' +
          '<defs id="diagram-lamp-diagram-defs"/>' +
          '<g class="fragment reshape" data-fragment-index="1" style="--delay: 0s; --duration: 0.9s"/>' +
          '<g class="fragment reshape" data-fragment-index="0" style="--delay: 0.3s; --duration: 0.9s"/>' +
          '<g class="fragment teardown" data-fragment-index="0"/>' +
          '<circle r="20" class="fragment transient arrive" data-fragment-index="1" style="--delay: 0.9s"/>' +
          '<rect id="diagram-lamp-lamp" x="0" y="0" width="10" height="10" data-reshaped-0-width="20" data-unseen-at="0" data-reshaped-1-x="30"/>' +
          '<g id="diagram-lamp-base" transform="translate(0 0)" data-reshaped-1-transform="translate(35 5)">' +
          '<rect x="0" y="20" width="10" height="2"/>' +
          '</g>' +
          '<text id="diagram-lamp-glow" x="0" y="5" data-gone-from="0">On</text>' +
          '<circle r="5" class="fragment transient arrive" data-fragment-index="1" style="--delay: 0.9s"/>' +
          '</svg>',
        '</div>',
        '<template class="diagram-captions">' +
          '<p data-caption="rest">A lamp.</p>' +
          '<p data-caption="0">A lamp, here.</p>' +
          '<p data-caption="1">It dims and widens, unseen.</p>' +
          '<p data-caption="2">It moves, in the shadow.</p>' +
          '</template>',
        '</div>',
        ''
      ].join('\n')
    );
  });

  it('fails on a part of this drawing left out, which would vanish when cutting to the other', () => {
    assert.throws(
      () =>
        generated(moved => [
          step(
            'It moves.',
            moved.into('lamp', 'base'),
            moved.arriving(['shade', 'shadow'])
          )
        ]),
      new Error(
        'lamp.svg: a <text> "glow" shown at its end has neither left, moved nor arrived'
      )
    );
  });

  it('fails on a part of the other drawing left out, which would appear when cutting to it', () => {
    assert.throws(
      () =>
        generated(moved => [
          step(
            'It moves.',
            moved.leaving('glow'),
            moved.into('lamp', 'base'),
            moved.arriving(['shade'])
          )
        ]),
      new Error(
        'lamp.svg: a <circle> "shadow" shown as the other starts has neither left, moved nor arrived'
      )
    );
  });

  it('fails on a part changed after it moved into the other drawing', () => {
    assert.throws(
      () =>
        generated(moved => [
          step(
            'It moves.',
            moved.leaving('glow'),
            moved.into('lamp', 'base'),
            moved.arriving(['shade', 'shadow'])
          ),
          step('It widens.', moved.reshaped({ lamp: { width: '30' } }))
        ]),
      new Error(
        'lamp.svg: "lamp" changes after it moves into the drawing it becomes'
      )
    );
  });

  it('fails on a part drawn as two different shapes', () => {
    assert.throws(
      () =>
        generated(
          moved => [step('It moves.', moved.into('lamp'))],
          HEAD + '<circle id="lamp" r="10"/></svg>'
        ),
      new Error(
        '"lamp" is a <circle> here and a <rect> in the drawing it becomes'
      )
    );
  });
});
