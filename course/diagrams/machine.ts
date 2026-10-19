// The toy machine of "How a computer works": an 8-bit processor and a memory of
// sixteen cells holding the program of the trace, a multiplication by repeated
// addition. Its steps are to follow the trace.
import { diagram } from '../src/diagrams/build';

export default diagram({
  captions: {
    rest:
      'A processor and a memory of sixteen cells, connected by a data bus and ' +
      'an address bus. The memory holds a program that multiplies 3 by 2 by ' +
      'adding 3 twice.',
    start: 'The program is in memory, and the program counter is at 0.'
  },
  steps: []
});
