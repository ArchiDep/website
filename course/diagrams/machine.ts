// The toy machine of "How a computer works": an 8-bit processor and a memory of
// sixteen cells holding the program of the trace, a multiplication by repeated
// addition. Its steps are the program's trace, worked out by the interpreter
// in `machine/trace.ts`, each step told with the machine's vocabulary.
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
} from '../src/diagrams/build/machine';
import { CLOCK, trace, type StepState } from './machine/trace';

// The parts a step can be about; the others are faded while it is the current
// one. The control unit takes part in every step, and is never faded; the
// clock is in focus when it ticks, at the step starting each phase.
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
  ...CLOCK,
  ...Array.from({ length: 16 }, (_, i) => `cell-${i}`)
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

const { start, steps } = trace();

export default diagram({
  captions: {
    rest:
      'A processor and a memory of sixteen cells, connected by a data bus and ' +
      'an address bus. The memory holds a program that multiplies 3 by 2 by ' +
      'adding 3 twice, and leaves its result in cell 14. The program counter ' +
      'is at 0, ready to start.',
    start:
      'The program is in memory, and the program counter is at 0. It ' +
      'multiplies 3 by 2 by adding 3 twice, and leaves its result in cell 14.'
  },
  start: Object.entries(start).map(([slot, held]) => value(slot, held)),
  steps: steps.map(state => step(state.caption, ...actionsOf(state)))
});
