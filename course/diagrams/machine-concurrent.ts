// The booted machine with a single core, and two programs in memory, A and B,
// coloured as the two rows of the coffee queues on the slide before. In one
// step, the core runs two of A's instructions, then the kernel, which switches
// it to B, then two of B's, then the kernel again, and so on until both
// programs are done, each picking up where it stopped: concurrency, the
// programs taking turns on one core. Only the core and the memory are in focus,
// the rest drawn faded.
import { diagram, step, walksAt, works } from '../src/diagrams/build/machine';

// How long each instruction stays lit: slow enough to follow which program
// runs.
const EACH = 0.5;
const PAIRS = [0, 1, 2].map(pair => [2 * pair, 2 * pair + 1]);
// The kernel's code that switches the core from one program to the other.
const SWITCH = 'kernel-cell-2';

const turns = PAIRS.flatMap(([first, second]) => [
  `a-cell-${first}`,
  `a-cell-${second}`,
  SWITCH,
  `b-cell-${first}`,
  `b-cell-${second}`,
  ...(second === 5 ? [] : [SWITCH])
]);

export default diagram({
  captions: {
    rest:
      'This diagram shows a single core, and two programs in memory, A and B, beside the kernel ' +
      'and init. The core runs a few of one program’s instructions, then the ' +
      'kernel switches it to the other: the programs take turns, they are ' +
      'concurrent.',
    start: 'A single core, and two programs in memory, A and B, both to run.'
  },
  steps: [
    step(
      'The core runs some of program A’s instructions, then the kernel, ' +
        'which switches the core to program B, then some of B’s, and so on: ' +
        'each program picks up where it stopped. The programs take turns: ' +
        'they are concurrent.',
      works(),
      walksAt(EACH, ...turns)
    )
  ]
});
