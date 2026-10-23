// The machine of `machine-concurrent` once a second core fades in under the
// first, on the same buses and the same memory. Each core then runs one of the
// two programs, A and B, both at the same time: parallelism. Then B ends, and A
// runs alone on the first core, the second idle: a program not written for
// several cores does not use them. A ends in turn, and program C, written for
// several cores, starts and runs on both, as two threads sharing its memory.
// It starts as the slide before leaves its machine, the second core not there
// yet.
import {
  diagram,
  fills,
  grows,
  show,
  step,
  teardown,
  walksAt,
  works
} from '../src/diagrams/build/machine';

// As on the slide before, so that the same instructions take the same time.
const EACH = 0.5;
// How long a band takes to fill, before its data widens beside it.
const FILL = 1.6;
const cells = (program: string, ...indices: number[]): string[] =>
  indices.map(i => `${program}-cell-${i}`);
const ALL = [0, 1, 2, 3, 4, 5];

export default diagram({
  captions: {
    rest:
      'This diagram shows two cores, and two programs in memory, A and B, beside the kernel and ' +
      'init. Each core runs one of the programs, both at the same time: they ' +
      'are parallel.',
    start: 'A single core, and two programs in memory, A and B, both to run.'
  },
  steps: [
    step(
      'A second core: another complete processor, on the same buses as the ' +
        'first, reading the same memory.',
      show('core-2', 'path-core-2-address-bus', 'path-core-2-data-bus')
    ),
    step(
      'Each core runs one program: the first core runs program A’s ' +
        'instructions while the second runs program B’s, at the same time. ' +
        'The programs run in parallel.',
      works(),
      works('cog-2'),
      walksAt(EACH, ...cells('a', ...ALL)),
      walksAt(EACH, ...cells('b', ...ALL))
    ),
    step(
      'Program B ends: the kernel frees its memory.',
      works(),
      teardown(['band-b'])
    ),
    step(
      'Program A runs alone: only the first core works. Program A was not ' +
        'written to use more than one core, so the second core stays idle.',
      works(),
      walksAt(EACH, ...cells('a', ...ALL))
    ),
    step(
      'Program A ends, and the kernel starts program C, which is written to ' +
        'run on several cores at once.',
      works(),
      teardown(['band-a']),
      fills('band-c'),
      grows('data-c', { after: FILL })
    ),
    step(
      'Program C runs on both cores at the same time: each core runs a ' +
        'different part of program C’s instructions, as two threads of the ' +
        'same program, sharing its memory.',
      works(),
      works('cog-2'),
      walksAt(EACH, ...cells('c', 0, 1, 2)),
      walksAt(EACH, ...cells('c', 3, 4, 5))
    )
  ]
});
