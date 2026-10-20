import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { diagram, show, step } from '.';
import { familyOf, generate, sharedFileOf, sync } from './generate';

describe('familyOf', () => {
  it('is the family the root names', () => {
    assert.equal(
      familyOf(
        '<svg xmlns="http://www.w3.org/2000/svg" data-family="clockwork"/>',
        'cuckoo.svg'
      ),
      'clockwork'
    );
  });

  it('is none for a root that names no family', () => {
    assert.equal(
      familyOf('<svg xmlns="http://www.w3.org/2000/svg"/>', 'kettle.svg'),
      null
    );
  });
});

describe('sharedFileOf', () => {
  it("is the architecture diagrams' file for no family", () => {
    assert.equal(sharedFileOf(null), 'shared.svg');
  });

  it('is named after the family', () => {
    assert.equal(sharedFileOf('gearbox'), 'shared-gearbox.svg');
  });
});

describe('sync', () => {
  it('replaces the contents of every part the shared file has an id for, and nothing else', () => {
    const shared =
      '<svg xmlns="http://www.w3.org/2000/svg">' +
      '<title>Shared</title>' +
      '<style id="diagram-styles">.box { fill: red; }</style>' +
      '<g id="legend"><text>Legend</text></g>' +
      '<rect class="sample"/>' +
      '</svg>';
    const drawing =
      '<svg xmlns="http://www.w3.org/2000/svg">' +
      '<title>Mine</title>' +
      '<style id="diagram-styles">.box { fill: blue; }</style>' +
      '<rect class="box"/>' +
      '<g id="legend" transform="translate(5 6)"><text>Old</text></g>' +
      '</svg>';

    assert.equal(
      sync(drawing, shared, 'mine.svg', 'shared.svg'),
      '<svg xmlns="http://www.w3.org/2000/svg">' +
        '<title>Mine</title>' +
        '<style id="diagram-styles">.box { fill: red; }</style>' +
        '<rect class="box"/>' +
        '<g id="legend" transform="translate(5 6)"><text>Legend</text></g>' +
        '</svg>\n'
    );
  });

  it('needs no legend when the family shares none', () => {
    const shared =
      '<svg xmlns="http://www.w3.org/2000/svg" data-family="engine">' +
      '<defs id="diagram-defs"><marker id="arrow"/></defs>' +
      '</svg>';
    const drawing =
      '<svg xmlns="http://www.w3.org/2000/svg" data-family="engine">' +
      '<defs id="diagram-defs"/>' +
      '<path marker-end="url(#arrow)"/>' +
      '</svg>';

    assert.equal(
      sync(drawing, shared, 'piston.svg', 'shared-engine.svg'),
      '<svg xmlns="http://www.w3.org/2000/svg" data-family="engine">' +
        '<defs id="diagram-defs"><marker id="arrow"/></defs>' +
        '<path marker-end="url(#arrow)"/>' +
        '</svg>\n'
    );
  });

  it('fails for a drawing without a part its family shares', () => {
    const shared =
      '<svg xmlns="http://www.w3.org/2000/svg">' +
      '<style id="diagram-styles"/>' +
      '<g id="legend"/>' +
      '</svg>';
    const drawing =
      '<svg xmlns="http://www.w3.org/2000/svg">' +
      '<style id="diagram-styles"/>' +
      '</svg>';

    assert.throws(
      () => sync(drawing, shared, 'pump.svg', 'shared-hydraulics.svg'),
      new Error(
        'pump.svg: there is no element with the id "legend", which shared-hydraulics.svg shares'
      )
    );
  });
});

describe('generate', () => {
  it('makes the partial a page or a deck includes', () => {
    const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" class="diagram" viewBox="0 0 40 20" width="40" height="20">' +
      '<title>A lamp</title>' +
      '<style id="diagram-styles">.on { fill: yellow; } /* Paler */ svg.diagram :is(.dim, .off)[marker-end], .out { marker-end: url(#tip); } .far { fill: url(#elsewhere); }</style>' +
      '<defs id="diagram-defs"><marker id="tip"/></defs>' +
      '<!-- lit later -->' +
      '<rect id="bulb" class="on" x="5" y="5" width="10" height="10"/>' +
      '<path d="M15 10 H35" marker-end="url(#tip)"/>' +
      '</svg>';

    assert.equal(
      generate({
        name: 'lamp',
        svg,
        definition: diagram({
          captions: { rest: 'A lamp, lit.', start: 'A lamp,\n  off.' },
          steps: [step('It lights up.', show('bulb'))]
        }),
        motion: '.fragment { opacity: 0; }'
      }),
      [
        '<!-- Generated from diagrams/lamp.svg and lamp.ts by "npm run diagrams": edit those instead. -->',
        '<div class="diagram-figure" data-diagram="lamp">',
        '<div class="diagram-canvas">',
        '<svg xmlns="http://www.w3.org/2000/svg" class="diagram" viewBox="0 0 40 20" role="img" aria-labelledby="diagram-lamp-title" data-diagram="lamp">' +
          '<title id="diagram-lamp-title">A lamp</title>' +
          // A rule referring to the drawing's own definitions applies to it
          // only, whichever its selectors start from
          '<style id="diagram-lamp-diagram-styles">.on { fill: yellow; } /* Paler */ ' +
          "svg.diagram[data-diagram='lamp'] :is(.dim, .off)[marker-end], svg.diagram[data-diagram='lamp'] .out { marker-end: url(#diagram-lamp-tip); } " +
          '.far { fill: url(#elsewhere); }</style>' +
          '<style class="diagram-motion">.fragment { opacity: 0; }</style>' +
          '<defs id="diagram-lamp-diagram-defs"><marker id="diagram-lamp-tip"/></defs>' +
          '<rect id="diagram-lamp-bulb" class="fragment on" x="5" y="5" width="10" height="10" data-fragment-index="0"/>' +
          '<path d="M15 10 H35" marker-end="url(#diagram-lamp-tip)"/>' +
          '</svg>',
        '</div>',
        '<template class="diagram-captions">' +
          '<p data-caption="rest">A lamp, lit.</p>' +
          '<p data-caption="0">A lamp, off.</p>' +
          '<p data-caption="1">It lights up.</p>' +
          '</template>',
        '</div>',
        ''
      ].join('\n')
    );
  });

  it('runs the checks a vocabulary asks for once every step is built', () => {
    const svg =
      '<svg xmlns="http://www.w3.org/2000/svg">' +
      '<title>A bell</title>' +
      '<defs id="diagram-defs"/>' +
      '</svg>';
    let rung = false;

    assert.throws(
      () =>
        generate({
          name: 'bell',
          svg,
          definition: diagram({
            captions: { rest: 'A bell.', start: 'A bell, still.' },
            steps: [
              step('It is struck.', builder =>
                builder.whenBuilt(() => {
                  throw new Error(`rung by the end: ${String(rung)}`);
                })
              ),
              step('It rings.', () => {
                rung = true;
              })
            ]
          }),
          motion: ''
        }),
      new Error('rung by the end: true')
    );
  });
});
