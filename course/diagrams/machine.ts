// The toy machine of "How a computer works": an 8-bit processor and a memory of
// sixteen cells holding the program of the trace, a multiplication by repeated
// addition. Its steps follow the trace as the room plays it, each transfer a
// step of its own, and each phase of the cycle first a step of its own, to
// explain it; for now, only its first instruction, LOAD 14.
import {
  annotate,
  diagram,
  focusOn,
  lit,
  live,
  reads,
  step,
  value
} from '../src/diagrams/build/machine';

// The parts a step can be about; the others are faded while it is the current
// one. The control unit and the clock take part in every step, and are never
// faded.
const focus = focusOn([
  'program-counter',
  'path-pc-selector',
  'path-ir-selector',
  'path-ir-pc',
  'path-bus-ir',
  'path-acc-bus',
  'path-alu-acc',
  'path-bus-alu',
  'path-acc-alu',
  'path-selector-address-bus',
  'path-data-bus-memory',
  'path-address-bus-memory',
  'data-bus',
  'address-bus',
  'selector',
  'wire-select',
  'wire-count',
  'instruction-register',
  'accumulator',
  'alu',
  'wire-zero',
  'wire-subtract',
  'memory',
  'wire-read-write',
  ...Array.from({ length: 16 }, (_, i) => `cell-${i}`)
]);

// Where the live wires run, in the drawing's coordinates: from the register or
// the cell that gives the value to the one that takes it.
const PC_TO_MEMORY = 'M216 55 H476 L524 75 H738';
const IR_TO_MEMORY = 'M293 210 V95 H476 L524 75 H738';
const CELL_0_TO_IR = 'M806 80 H801 V96 H750 V491 H100 V244';
const CELL_14_TO_ACCUMULATOR = 'M806 528 H801 V512 H750 V491 H190 V389';

// What an address read from memory goes through.
const ADDRESS_TO_MEMORY = [
  'selector',
  'wire-select',
  'path-selector-address-bus',
  'address-bus',
  'path-address-bus-memory',
  'memory',
  'wire-read-write'
];
// What a value read from memory goes through.
const DATA_FROM_MEMORY = [
  'memory',
  'wire-read-write',
  'path-data-bus-memory',
  'data-bus'
];

export default diagram({
  captions: {
    rest:
      'A processor and a memory of sixteen cells, connected by a data bus and ' +
      'an address bus. The memory holds a program that multiplies 3 by 2 by ' +
      'adding 3 twice.',
    start: 'The program is in memory, and the program counter is at 0.'
  },
  start: [value('program-counter', 0)],
  steps: [
    step(
      'Fetch: the control unit fetches the next instruction from memory.',
      lit('step-fetch'),
      focus()
    ),
    step(
      'The control unit tells the selector to let the program counter’s ' +
        'address through, and the memory to read the cell at that address, 0.',
      lit('step-fetch', 'wire-select', 'cell-0'),
      reads(),
      live(PC_TO_MEMORY),
      focus(
        'program-counter',
        'path-pc-selector',
        ...ADDRESS_TO_MEMORY,
        'cell-0'
      )
    ),
    step(
      'The control unit tells the memory to put the bits of cell 0 on the ' +
        'data bus, and the instruction register to take them.',
      lit('step-fetch', 'cell-0'),
      reads(),
      live(CELL_0_TO_IR),
      value('instruction-register', 0b0001_1110),
      focus(
        ...DATA_FROM_MEMORY,
        'cell-0',
        'path-bus-ir',
        'instruction-register'
      )
    ),
    step(
      'The control unit tells the program counter to add 1, ready for the ' +
        'next instruction.',
      lit('step-fetch', 'wire-count'),
      value('program-counter', 1),
      focus('program-counter', 'wire-count')
    ),
    step(
      'Decode: the control unit decodes the instruction in the instruction ' +
        'register, to know what to do.',
      lit('step-decode'),
      focus('instruction-register')
    ),
    step(
      'The instruction’s 4 bits of operation are LOAD, and its 4 bits of ' +
        'address 14: the bits of cell 0 were an instruction.',
      lit('step-decode'),
      value('decoded-operation', 'LOAD'),
      value('decoded-address', '14'),
      // The annotation in memory is an aside: the step is about the control
      // unit decoding the instruction register, not the cell.
      annotate('cell-0'),
      focus('instruction-register')
    ),
    step(
      'Execute: the control unit carries out the instruction.',
      lit('step-execute'),
      focus()
    ),
    step(
      'The control unit tells the selector to let the instruction’s address ' +
        'through, and the memory to read the cell at that address, 14.',
      lit('step-execute', 'wire-select', 'cell-14'),
      reads(),
      live(IR_TO_MEMORY),
      focus(
        'instruction-register',
        'path-ir-selector',
        ...ADDRESS_TO_MEMORY,
        'cell-14'
      )
    ),
    step(
      'The control unit tells the memory to put the bits of cell 14 on the ' +
        'data bus, and the accumulator to take them: the accumulator holds 0.',
      lit('step-execute', 'cell-14'),
      reads(),
      live(CELL_14_TO_ACCUMULATOR),
      value('accumulator', 0),
      annotate('cell-14'),
      focus(...DATA_FROM_MEMORY, 'cell-14', 'path-acc-bus', 'accumulator')
    )
  ]
});
