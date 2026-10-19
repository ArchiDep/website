// The machine of "How a computer works" as it boots: a 64-bit processor, with
// the firmware, the memory and the disk controller on its buses, and the
// storage behind the controller. Its steps are to follow the boot.
import { diagram } from '../src/diagrams/build';

export default diagram({
  captions: {
    rest:
      'A 64-bit processor, connected by a data bus and an address bus to the ' +
      'firmware, the memory and the disk controller. The storage is behind ' +
      'the disk controller, which the processor asks to copy from it into ' +
      'memory.',
    start: 'The machine is powered on. There is no program in memory yet.'
  },
  steps: []
});
