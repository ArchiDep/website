import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { copyOf } from '../actions';
import { generate } from '../generate';
import {
  diagram,
  focusOn,
  lit,
  live,
  reads,
  step,
  tick,
  value,
  writes,
  type Action
} from '.';

/**
 * The partial of a diagram named `m`, drawn with `body`, its captions `R` at
 * rest and `S` at the start, and its steps captioned in order.
 */
function generated(
  body: string,
  steps: readonly (readonly Action[])[],
  start: readonly Action[] = []
): string {
  return generate({
    name: 'm',
    svg:
      '<svg xmlns="http://www.w3.org/2000/svg" class="diagram"><title>T</title>' +
      `<style id="diagram-styles"/><defs id="diagram-defs"/>${body}</svg>`,
    definition: diagram({
      captions: { rest: 'R', start: 'S' },
      start,
      steps: steps.map((actions, i) => step(`step ${i + 1}`, ...actions))
    }),
    motion: ''
  });
}

/**
 * What `generated` makes of a drawing that came out as `body`, with as many
 * steps.
 */
function partial(body: string, steps: number): string {
  return [
    '<!-- Generated from diagrams/m.svg and m.ts by "npm run diagrams": edit those instead. -->',
    '<div class="diagram-figure" data-diagram="m">',
    '<div class="diagram-canvas">',
    '<svg xmlns="http://www.w3.org/2000/svg" class="diagram" role="img" aria-labelledby="diagram-m-title">' +
      '<title id="diagram-m-title">T</title>' +
      '<style id="diagram-m-diagram-styles"/><style class="diagram-motion"></style>' +
      `<defs id="diagram-m-diagram-defs"/>${body}</svg>`,
    '</div>',
    '<template class="diagram-captions">' +
      '<p data-caption="rest">R</p><p data-caption="0">S</p>' +
      Array.from(
        { length: steps },
        (_, i) => `<p data-caption="${i + 1}">step ${i + 1}</p>`
      ).join('') +
      '</template>',
    '</div>',
    ''
  ].join('\n');
}

describe('value', () => {
  it("shows a register's value in its bits and in decimal, from the step that gives it until the next, and its value at the start at rest too", () => {
    assert.equal(
      generated(
        '<g id="counter"><rect class="bit" x="0" y="0" width="10" height="10"/><rect class="bit" x="10" y="0" width="10" height="10"/></g>' +
          '<text id="decimal-counter" class="decimal transient" x="30" y="5">0</text>',
        [[value('counter', 2)], [value('counter', 3)]],
        [value('counter', 1)]
      ),
      partial(
        '<g class="fragment teardown" data-fragment-index="1"/>' +
          '<g class="fragment teardown" data-fragment-index="0"/>' +
          '<g id="diagram-m-counter"><rect class="bit" x="0" y="0" width="10" height="10"/><rect class="bit" x="10" y="0" width="10" height="10"/></g>' +
          '<g class="fragment transient register-value" data-fragment-index="1"><text class="bit-value" x="5" y="5">1</text><text class="bit-value" x="15" y="5">1</text></g>' +
          '<g class="fragment transient register-value" data-fragment-index="0" data-gone-from="1"><text class="bit-value" x="5" y="5">1</text><text class="bit-value" x="15" y="5">0</text></g>' +
          '<g class="register-value" data-gone-from="0"><text class="bit-value" x="5" y="5">0</text><text class="bit-value" x="15" y="5">1</text></g>' +
          '<text id="diagram-m-decimal-counter" class="decimal transient" x="30" y="5">0</text>' +
          '<text class="fragment decimal transient" x="30" y="5" data-fragment-index="1">3</text>' +
          '<text class="fragment decimal transient" x="30" y="5" data-fragment-index="0" data-gone-from="1">2</text>' +
          '<text class="decimal" x="30" y="5" data-gone-from="0">1</text>',
        2
      )
    );
  });

  it('fills a copy of a template with the value, until a step gives nothing', () => {
    assert.equal(
      generated(
        '<g id="field" class="transient"><rect class="mask"/><text class="decoded" x="5" y="5">?</text></g>',
        [[value('field', 'LOAD')], [value('field', null)]]
      ),
      partial(
        '<g class="fragment teardown" data-fragment-index="1"/>' +
          '<g id="diagram-m-field" class="transient"><rect class="mask"/><text class="decoded" x="5" y="5">?</text></g>' +
          '<g class="fragment transient" data-fragment-index="0" data-gone-from="1"><rect class="mask"/><text class="decoded" x="5" y="5">LOAD</text></g>',
        2
      )
    );
  });

  it('shows a text the drawing shows, at rest and from the start, until a step gives it a value', () => {
    assert.equal(
      generated(
        '<g id="cell-1"><text id="bits-1" class="bits">0000 0000</text>' +
          '<text id="annotation-1" class="annotation">0</text></g>' +
          '<g id="cell-2"><text id="annotation-2" class="annotation">1</text></g>',
        [
          [value('bits-1', '0000 0011'), value('annotation-1', null)],
          [value('annotation-1', '3')]
        ],
        [value('bits-1', '0000 0000')]
      ),
      partial(
        '<g class="fragment teardown" data-fragment-index="0"/>' +
          '<g id="diagram-m-cell-1">' +
          '<text id="diagram-m-bits-1" class="bits" data-gone-from="0">0000 0000</text>' +
          '<text class="fragment transient bits" data-fragment-index="0">0000 0011</text>' +
          '<text id="diagram-m-annotation-1" class="annotation" data-gone-from="0">0</text>' +
          '<text class="fragment transient annotation" data-fragment-index="1">3</text>' +
          '</g>' +
          '<g id="diagram-m-cell-2"><text id="diagram-m-annotation-2" class="annotation">1</text></g>',
        2
      )
    );
  });

  it('fails for a value at the start that a text the drawing shows does not hold', () => {
    assert.throws(
      () =>
        generated(
          '<text id="bits-1" class="bits">0000 0110</text>',
          [[value('bits-1', '0000 0011')]],
          [value('bits-1', '0000 0000')]
        ),
      new Error(
        '"bits-1" is drawn holding "0000 0110", which is what it holds from the start, not "0000 0000"'
      )
    );
  });

  it('fails for a value too wide for the register', () => {
    assert.throws(
      () =>
        generated(
          '<g id="flag"><rect class="bit" x="0" y="0" width="10" height="10"/></g>',
          [[value('flag', 2)]]
        ),
      new Error('2 does not fit in the 1 bits of "flag"')
    );
  });
});

describe('lit', () => {
  it('lights a copy of the first shape for each stretch of steps it is lit', () => {
    assert.equal(
      generated(
        '<g id="pill"><text>Fetch</text><rect class="step" x="1" y="2" width="3" height="4"/></g>',
        [[lit('pill')], [lit('pill')], [], [lit('pill')]]
      ),
      partial(
        '<g class="fragment teardown" data-fragment-index="2"/>' +
          '<g id="diagram-m-pill"><text>Fetch</text><rect class="step" x="1" y="2" width="3" height="4"/>' +
          '<rect class="fragment transient lit step" x="1" y="2" width="3" height="4" data-fragment-index="3"/>' +
          '<rect class="fragment transient lit step" x="1" y="2" width="3" height="4" data-fragment-index="0" data-gone-from="2"/></g>',
        4
      )
    );
  });

  it('lights a copy of an element that is a shape itself, such as a wire', () => {
    assert.equal(
      generated(
        '<path id="signal" class="wire" d="M0 9 V1" marker-end="url(#tip)"/>',
        [[lit('signal')], []]
      ),
      partial(
        '<g class="fragment teardown" data-fragment-index="1"/>' +
          '<path id="diagram-m-signal" class="wire" d="M0 9 V1" marker-end="url(#tip)"/>' +
          '<path class="fragment transient lit wire" d="M0 9 V1" marker-end="url(#tip)" data-fragment-index="0" data-gone-from="1"/>',
        2
      )
    );
  });
});

describe('tick', () => {
  it('lights the clock and its wire for each step it ticks at, each on its own', () => {
    assert.equal(
      generated(
        '<path id="clock-wave" class="clock-wave" d="M0 5 H5"/>' +
          '<g id="wire-clock"><path class="wire" d="M5 5 H9"/><text>to every register</text></g>',
        [[tick()], [tick()]]
      ),
      partial(
        '<g class="fragment teardown" data-fragment-index="1"/>' +
          '<path id="diagram-m-clock-wave" class="clock-wave" d="M0 5 H5"/>' +
          '<path class="fragment transient lit tick clock-wave" d="M0 5 H5" data-fragment-index="1"/>' +
          '<path class="fragment transient lit tick clock-wave" d="M0 5 H5" data-fragment-index="0" data-gone-from="1"/>' +
          '<g id="diagram-m-wire-clock"><path class="wire" d="M5 5 H9"/>' +
          '<path class="fragment transient lit tick wire" d="M5 5 H9" data-fragment-index="1"/>' +
          '<path class="fragment transient lit tick wire" d="M5 5 H9" data-fragment-index="0" data-gone-from="1"/>' +
          '<text>to every register</text></g>',
        2
      )
    );
  });
});

describe('reads and writes', () => {
  it("light the R or the W of the memory's controls", () => {
    assert.equal(
      generated(
        '<text id="read-write" class="read-write" x="1" y="2">R/W</text>',
        [[reads()], [writes()]]
      ),
      partial(
        '<g class="fragment teardown" data-fragment-index="1"/>' +
          '<text id="diagram-m-read-write" class="read-write" x="1" y="2">R/W</text>' +
          '<text class="fragment transient lit read-write" x="1" y="2" data-fragment-index="1"><tspan class="unlit">R/</tspan>W</text>' +
          '<text class="fragment transient lit read-write" x="1" y="2" data-fragment-index="0" data-gone-from="1">R<tspan class="unlit">/W</tspan></text>',
        2
      )
    );
  });
});

describe('live', () => {
  it('draws one live wire for each stretch of steps a path is live', () => {
    assert.equal(
      generated('<g id="live-wires"/>', [
        [live('M0 0 H5')],
        [live('M0 0 H5')],
        [live('M5 0 V5')]
      ]),
      partial(
        '<g class="fragment teardown" data-fragment-index="2"/>' +
          '<g id="diagram-m-live-wires">' +
          '<g class="fragment transient live" data-fragment-index="0" data-gone-from="2"><path class="live-casing" d="M0 0 H5"/><path class="live-wire" d="M0 0 H5"/><path class="live-current" d="M0 0 H5"/></g>' +
          '<g class="fragment transient live" data-fragment-index="2"><path class="live-casing" d="M5 0 V5"/><path class="live-wire" d="M5 0 V5"/><path class="live-current" d="M5 0 V5"/></g>' +
          '</g>',
        3
      )
    );
  });
});

describe('focusOn', () => {
  it('fades the parts a step is not about, at the steps that say what they are about', () => {
    const focus = focusOn(['left', 'right']);

    assert.equal(
      generated('<g id="left"/><g id="right"/>', [
        [focus('left')],
        [],
        [focus('right')]
      ]),
      partial(
        '<g class="fragment focus" data-fragment-index="2"/>' +
          '<g class="fragment focus" data-fragment-index="0"/>' +
          '<g id="diagram-m-left" data-faded-at="2"/>' +
          '<g id="diagram-m-right" data-faded-at="0"/>',
        3
      )
    );
  });

  it('fades the copies standing for a part too, such as one brought in from another drawing', () => {
    const focus = focusOn(['left', 'shade']);
    const bringShade: Action = builder => {
      const copy = copyOf(builder.element('template'));
      builder.element('template').parentNode?.appendChild(copy);
      builder.copied('shade', copy);
    };

    assert.equal(
      generated('<g id="left"/><circle id="template" r="1"/>', [
        [bringShade, focus('left')],
        [focus('shade')]
      ]),
      partial(
        '<g class="fragment focus" data-fragment-index="1"/>' +
          '<g class="fragment focus" data-fragment-index="0"/>' +
          '<g id="diagram-m-left" data-faded-at="1"/>' +
          '<circle id="diagram-m-template" r="1"/>' +
          '<circle r="1" data-faded-at="0"/>',
        2
      )
    );
  });

  it('fails for a part it was not given', () => {
    const focus = focusOn(['up']);

    assert.throws(
      () => generated('<g id="up"/><g id="down"/>', [[focus('down')]]),
      new Error('m.svg: "down" is not one of the parts focus is given on')
    );
  });
});
