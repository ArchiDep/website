// The toy machine of "How a computer works": an 8-bit processor and a memory of
// sixteen cells holding the program of the trace, a multiplication by repeated
// addition. It opens with both drawn opaque, then shows the memory and the
// program in it, the buses, and the processor's components. Its other steps are
// the program's trace, worked out by the interpreter in `machine/trace.ts`,
// each step told with the machine's vocabulary.
import {
  diagram,
  focusOn,
  lit,
  live,
  reads,
  step,
  teardown,
  tick,
  value,
  writes,
  type Action
} from '../src/diagrams/build/machine';
import { CLOCK, MEMORY_CELLS, trace, type StepState } from './machine/trace';

// What the buses are drawn as outside the processor drawn opaque, the paths
// coming out of it included.
const BUSES = [
  'data-bus',
  'address-bus',
  'path-selector-address-bus',
  'path-bus-alu',
  'path-data-bus-memory',
  'path-address-bus-memory'
];

// The parts a step can be about; the others are faded while it is the current
// one. The control unit takes part in every step, and is never faded; the
// clock is in focus when it ticks, at the step starting each phase.
const focus = focusOn([
  'processor-cover',
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
  ...CLOCK,
  ...MEMORY_CELLS
]);

function actionsOf(state: StepState): Action[] {
  return [
    ...(state.tick ? [tick()] : []),
    lit(...state.lit),
    ...(state.access === 'read' ? [reads()] : []),
    ...(state.access === 'write' ? [writes()] : []),
    ...state.live.map(path => live(path)),
    ...Object.entries(state.values).map(([slot, held]) => value(slot, held)),
    ...(state.focus === null ? [] : [focus(...state.focus)])
  ];
}

const { start, reading, steps } = trace();
const stepOf = (state: StepState) => step(state.caption, ...actionsOf(state));

export default diagram({
  captions: {
    rest:
      'A processor and a memory of sixteen cells, connected by a data bus and ' +
      'an address bus. The memory holds a program that multiplies 3 by 2 by ' +
      'adding 3 twice, and leaves its result in cell 14. The program counter ' +
      'is at 0, ready to start.',
    start:
      'A processor and a memory, connected by a data bus and an address bus.'
  },
  start: Object.entries(start).map(([slot, held]) => value(slot, held)),
  steps: [
    step(
      'The memory has sixteen cells, numbered 0 to 15, each holding 8 bits.',
      teardown(['memory-cover']),
      focus('memory', ...MEMORY_CELLS)
    ),
    ...reading.map(stepOf),
    step(
      'The address bus carries 4 bits, enough to pick one of the sixteen ' +
        'cells, as the address inputs of the addressable memory did. The data ' +
        'bus carries the 8 bits of a cell, to the memory or from it.',
      focus(...BUSES)
    ),
    step(
      'The processor, an 8-bit CPU, runs the program: it reads each ' +
        'instruction from memory, then does what it says.',
      focus('processor-cover')
    ),
    step(
      'Inside the processor: the program counter, the selector, the control ' +
        'unit with its instruction register, the accumulator, the ALU and the ' +
        'clock.',
      teardown(['processor-cover', 'data-bus-label'])
    ),
    ...steps.map(stepOf)
  ]
});
