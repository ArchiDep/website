import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';

import { DOMParser } from '@xmldom/xmldom';

import { PROGRAM, bitsOf, trace } from './trace';

const ADDRESS_TO_MEMORY = [
  'selector',
  'wire-select',
  'path-selector-address-bus',
  'address-bus',
  'path-address-bus-memory',
  'memory',
  'wire-read-write'
];
const DATA_FROM_MEMORY = [
  'memory',
  'wire-read-write',
  'path-data-bus-memory',
  'data-bus'
];

describe('trace', () => {
  it('tells the program, then its data, in the same memory, the memory in focus', () => {
    const inMemory = [
      'memory',
      'cell-0',
      'cell-1',
      'cell-2',
      'cell-3',
      'cell-4',
      'cell-5',
      'cell-6',
      'cell-7',
      'cell-8',
      'cell-9',
      'cell-10',
      'cell-11',
      'cell-12',
      'cell-13',
      'cell-14',
      'cell-15'
    ];
    assert.deepEqual(trace().reading, [
      {
        caption:
          'Cells 0 to 8 hold the program: its instructions, one per cell. ' +
          'It multiplies 3 by 2, by adding 3 twice.',
        tick: false,
        lit: [
          'cell-0',
          'cell-1',
          'cell-2',
          'cell-3',
          'cell-4',
          'cell-5',
          'cell-6',
          'cell-7',
          'cell-8'
        ],
        access: null,
        live: [],
        values: {},
        focus: inMemory
      },
      {
        caption:
          'Cells 12 to 15 hold its data, the numbers it works on, in the same memory as its instructions.',
        tick: false,
        lit: ['cell-12', 'cell-13', 'cell-14', 'cell-15'],
        access: null,
        live: [],
        values: {},
        focus: inMemory
      }
    ]);
  });

  it('begins by taking away the annotations of the cells it uses', () => {
    assert.deepEqual(trace().steps[0], {
      caption:
        'The processor knows none of this: to it, the memory holds only bits. A cell is an instruction or a number only once the processor uses it as one.',
      tick: false,
      lit: [],
      access: null,
      live: [],
      values: {
        'annotation-0': null,
        'annotation-1': null,
        'annotation-2': null,
        'annotation-3': null,
        'annotation-4': null,
        'annotation-5': null,
        'annotation-6': null,
        'annotation-7': null,
        'annotation-8': null,
        'annotation-12': null,
        'annotation-13': null,
        'annotation-14': null,
        'annotation-15': null
      },
      focus: [
        'memory',
        'cell-0',
        'cell-1',
        'cell-2',
        'cell-3',
        'cell-4',
        'cell-5',
        'cell-6',
        'cell-7',
        'cell-8',
        'cell-12',
        'cell-13',
        'cell-14',
        'cell-15'
      ]
    });
  });

  it('tells the first instruction in full, each phase opening with its tick and pill alone', () => {
    assert.deepEqual(trace().steps.slice(1, 10), [
      {
        caption:
          'Fetch: the clock ticks, and the control unit starts fetching the next instruction from memory.',
        tick: true,
        lit: ['step-fetch'],
        access: null,
        live: [],
        values: {},
        focus: ['clock', 'wire-clock']
      },
      {
        caption:
          'The control unit tells the selector to let the program counter’s address through, and the memory to read the cell at that address, 0.',
        tick: false,
        lit: ['step-fetch', 'wire-select', 'cell-0'],
        access: 'read',
        live: ['M216 55 H476 L524 75 H738'],
        values: {},
        focus: [
          'program-counter',
          'path-pc-selector',
          ...ADDRESS_TO_MEMORY,
          'cell-0'
        ]
      },
      {
        caption:
          'The control unit tells the memory to put the bits of cell 0 on the data bus, and the instruction register to take them.',
        tick: false,
        lit: ['step-fetch', 'cell-0'],
        access: 'read',
        live: ['M806 80 H801 V96 H750 V491 H100 V244'],
        values: { 'instruction-register': 0b0001_1110 },
        focus: [
          ...DATA_FROM_MEMORY,
          'cell-0',
          'path-bus-ir',
          'instruction-register'
        ]
      },
      {
        caption:
          'The control unit tells the program counter to add 1, ready for the next instruction.',
        tick: false,
        lit: ['step-fetch', 'wire-count'],
        access: null,
        live: [],
        values: { 'program-counter': 1 },
        focus: ['program-counter', 'wire-count']
      },
      {
        caption:
          'Decode: the clock ticks, and the control unit starts decoding the instruction in the instruction register, to know what to do.',
        tick: true,
        lit: ['step-decode'],
        access: null,
        live: [],
        values: {},
        focus: ['clock', 'wire-clock', 'instruction-register']
      },
      {
        caption:
          'The instruction’s 4 bits of operation are LOAD, and its 4 bits of address 14: the bits of cell 0 were an instruction.',
        tick: false,
        lit: ['step-decode'],
        access: null,
        live: [],
        values: {
          'decoded-operation': 'LOAD',
          'decoded-address': '14',
          'annotation-0': 'LOAD 14'
        },
        focus: ['instruction-register']
      },
      {
        caption:
          'Execute: the clock ticks, and the control unit starts carrying out the instruction.',
        tick: true,
        lit: ['step-execute'],
        access: null,
        live: [],
        values: {},
        focus: ['clock', 'wire-clock']
      },
      {
        caption:
          'The control unit tells the selector to let the instruction’s address through, and the memory to read the cell at that address, 14.',
        tick: false,
        lit: ['step-execute', 'wire-select', 'cell-14'],
        access: 'read',
        live: ['M293 210 V95 H476 L524 75 H738'],
        values: {},
        focus: [
          'instruction-register',
          'path-ir-selector',
          ...ADDRESS_TO_MEMORY,
          'cell-14'
        ]
      },
      {
        caption:
          'The control unit tells the memory to put the bits of cell 14 on the data bus, and the accumulator to take them: the accumulator holds 0.',
        tick: false,
        lit: ['step-execute', 'cell-14'],
        access: 'read',
        live: ['M806 528 H801 V512 H750 V491 H190 V389'],
        values: { accumulator: 0, 'annotation-14': '0' },
        focus: [...DATA_FROM_MEMORY, 'cell-14', 'path-acc-bus', 'accumulator']
      }
    ]);
  });

  it('tells an addition of the first pass at the medium pace, in six steps', () => {
    assert.deepEqual(trace().steps.slice(10, 16), [
      {
        caption:
          'Fetch: the clock ticks, and the control unit has the memory read cell 1, at the program counter’s address, into the instruction register.',
        tick: true,
        lit: ['step-fetch', 'wire-select', 'cell-1'],
        access: 'read',
        live: [
          'M216 55 H476 L524 75 H738',
          'M806 112 H801 V128 H750 V491 H100 V244'
        ],
        values: {
          'instruction-register': 0b0010_1100,
          'decoded-operation': null,
          'decoded-address': null
        },
        focus: [
          'clock',
          'wire-clock',
          'program-counter',
          'path-pc-selector',
          ...ADDRESS_TO_MEMORY,
          'path-data-bus-memory',
          'data-bus',
          'cell-1',
          'path-bus-ir',
          'instruction-register'
        ]
      },
      {
        caption:
          'The control unit tells the program counter to add 1, ready for the next instruction.',
        tick: false,
        lit: ['step-fetch', 'wire-count'],
        access: null,
        live: [],
        values: { 'program-counter': 2 },
        focus: ['program-counter', 'wire-count']
      },
      {
        caption:
          'Decode: the clock ticks, and the control unit decodes the instruction in the instruction register.',
        tick: true,
        lit: ['step-decode'],
        access: null,
        live: [],
        values: {},
        focus: ['clock', 'wire-clock', 'instruction-register']
      },
      {
        caption:
          'The instruction’s 4 bits of operation are ADD, and its 4 bits of address 12.',
        tick: false,
        lit: ['step-decode'],
        access: null,
        live: [],
        values: {
          'decoded-operation': 'ADD',
          'decoded-address': '12',
          'annotation-1': 'ADD 12'
        },
        focus: ['instruction-register']
      },
      {
        caption:
          'Execute: the clock ticks, and the control unit has the memory read cell 12, at the instruction’s address, and has the ALU add it to the accumulator.',
        tick: true,
        lit: ['step-execute', 'wire-select', 'cell-12'],
        access: 'read',
        live: [
          'M293 210 V95 H476 L524 75 H738',
          'M806 464 H801 V480 H750 V491 H631 V341 H520',
          'M330 389 V450 H560 V405 H520'
        ],
        values: { 'annotation-12': '3' },
        focus: [
          'clock',
          'wire-clock',
          'instruction-register',
          'path-ir-selector',
          ...ADDRESS_TO_MEMORY,
          'path-data-bus-memory',
          'data-bus',
          'cell-12',
          'path-bus-alu',
          'path-acc-alu',
          'accumulator',
          'alu'
        ]
      },
      {
        caption:
          'The ALU gives back 0 + 3 = 3, and the control unit tells the accumulator to take it: the accumulator holds 3.',
        tick: false,
        lit: ['step-execute'],
        access: null,
        live: ['M440 372 H374'],
        values: { accumulator: 3 },
        focus: ['alu', 'path-alu-acc', 'accumulator']
      }
    ]);
  });

  it('tells an instruction of the second pass at the fast pace, a step per phase', () => {
    assert.deepEqual(trace().steps.slice(53, 56), [
      {
        caption:
          'Fetch: the clock ticks, and the control unit has the memory read cell 2, at the program counter’s address, into the instruction register, and tells the program counter to add 1.',
        tick: true,
        lit: ['step-fetch', 'wire-select', 'wire-count', 'cell-2'],
        access: 'read',
        live: [
          'M216 55 H476 L524 75 H738',
          'M806 144 H801 V160 H750 V491 H100 V244'
        ],
        values: {
          'instruction-register': 0b0100_1110,
          'decoded-operation': null,
          'decoded-address': null
        },
        focus: [
          'clock',
          'wire-clock',
          'program-counter',
          'path-pc-selector',
          ...ADDRESS_TO_MEMORY,
          'wire-count',
          'path-data-bus-memory',
          'data-bus',
          'cell-2',
          'path-bus-ir',
          'instruction-register'
        ]
      },
      {
        caption:
          'Decode: the clock ticks, and the control unit decodes the instruction in the instruction register: STORE 14. The program counter has counted to 3.',
        tick: true,
        lit: ['step-decode'],
        access: null,
        live: [],
        values: {
          'decoded-operation': 'STORE',
          'decoded-address': '14',
          'program-counter': 3
        },
        focus: [
          'clock',
          'wire-clock',
          'instruction-register',
          'program-counter'
        ]
      },
      {
        caption:
          'Execute: the clock ticks, and the control unit has the memory write the accumulator’s bits, 6, into cell 14, at the instruction’s address.',
        tick: true,
        lit: ['step-execute', 'wire-select', 'cell-14'],
        access: 'write',
        live: [
          'M293 210 V95 H476 L524 75 H738',
          'M190 389 V491 H750 V512 H801 V528 H806'
        ],
        values: { 'bits-14': '0000 0110', 'annotation-14': '6' },
        focus: [
          'clock',
          'wire-clock',
          'instruction-register',
          'path-ir-selector',
          ...ADDRESS_TO_MEMORY,
          'accumulator',
          'path-acc-bus',
          'data-bus',
          'path-data-bus-memory',
          'cell-14'
        ]
      }
    ]);
  });

  it('stops the clock at HALT', () => {
    assert.deepEqual(trace().steps.at(-2), {
      caption:
        'Execute: the clock ticks a last time, and the control unit stops it, since the program is done.',
      tick: true,
      lit: ['step-execute'],
      access: null,
      live: [],
      values: {},
      focus: ['clock', 'wire-clock']
    });
  });

  it('ends on a step of its own, the whole machine in focus and only the result lit', () => {
    assert.deepEqual(trace().steps.at(-1), {
      caption:
        'The program is done, and the machine has stopped: cell 14 holds its result, 6.',
      tick: false,
      lit: ['cell-14'],
      access: null,
      live: [],
      values: {},
      focus: null
    });
  });

  it('starts with the program counter at 0', () => {
    assert.deepEqual(trace().start, { 'program-counter': 0 });
  });

  it('halts with the product, 6, in cell 14, and the counter down to 0', () => {
    assert.deepEqual(
      trace().memory,
      [
        0b0001_1110, 0b0010_1100, 0b0100_1110, 0b0001_1101, 0b0011_1111,
        0b0100_1101, 0b1000_1000, 0b0110_0000, 0b1111_0000, 0, 0, 0, 3, 0, 6, 1
      ]
    );
  });

  it('starts from the memory and the annotations the fully drawn diagram shows', () => {
    const { steps } = trace();
    const doc = new DOMParser().parseFromString(
      readFileSync(path.join(import.meta.dirname, '..', 'machine.svg'), 'utf8'),
      'image/svg+xml'
    );
    const drawn = (prefix: string): Record<string, string> =>
      Object.fromEntries(
        Array.from({ length: 16 }, (_, cell) => [
          cell,
          doc.getElementById(`${prefix}-${cell}`)?.textContent ?? null
        ]).filter(([, text]) => text !== null)
      );
    // The first value each annotation is given, once taken away.
    const annotations: Record<string, string> = {};
    for (const { values } of steps) {
      for (const [slot, value] of Object.entries(values)) {
        const cell = /^annotation-(\d+)$/u.exec(slot)?.[1];
        if (
          cell !== undefined &&
          typeof value === 'string' &&
          !(cell in annotations)
        ) {
          annotations[cell] = value;
        }
      }
    }

    assert.deepEqual(
      { bits: drawn('bits'), annotations: drawn('annotation') },
      {
        bits: Object.fromEntries(
          PROGRAM.map((word, cell) => [cell, bitsOf(word)])
        ),
        annotations
      }
    );
  });

  it('fails for a program that never halts', () => {
    assert.throws(
      () => trace([0b0110_0000]),
      new Error('The program has run 100 instructions without halting')
    );
  });

  it('fails for bits that are not an instruction', () => {
    assert.throws(
      () => trace([0b0000_0001]),
      new Error('0000 0001 is not an instruction')
    );
  });
});
