// The machine of "How a computer works" as it boots: a 64-bit processor, with
// the firmware, the memory and the disk controller on its buses, and the
// storage behind the controller. Its last step turns it into the machine drawn
// on the next slide, `machine-boot-opaque`, where the boot is followed.
import path from 'node:path';

import {
  becomes,
  diagram,
  drawingOf,
  step
} from '../src/diagrams/build/machine';

const opaque = drawingOf(
  path.join(import.meta.dirname, 'machine-boot-opaque.svg')
);

export default diagram({
  captions: {
    rest:
      'A 64-bit processor, connected by a data bus and an address bus to the ' +
      'firmware, the memory and the disk controller. The storage is behind ' +
      'the disk controller, which the processor asks to copy from it into ' +
      'memory.',
    start: 'The machine is powered on. There is no program in memory yet.'
  },
  steps: [
    step(
      'From now on, the processor is drawn as a box, a core of it: what is ' +
        'inside it is no longer shown, and the memory has more room.',
      becomes(opaque, {
        moved: [
          'processor',
          'processor-tab',
          'processor-pill',
          'path-processor-address-bus',
          'path-processor-data-bus',
          'data-bus-rail',
          'data-bus-label',
          'address-bus-rail',
          'address-bus-label',
          'path-data-bus-firmware',
          'path-address-bus-firmware',
          'firmware-read-only',
          'firmware-box',
          'firmware-label',
          'firmware-chip',
          'path-data-bus-memory',
          'path-address-bus-memory',
          'memory-box',
          'memory-label',
          'memory-note',
          'path-data-bus-disk-controller',
          'path-address-bus-disk-controller',
          'disk-controller',
          'path-disk-controller-storage',
          'storage-box',
          'storage-label'
        ],
        leaving: [
          'processor-name',
          'control-unit',
          'alu-others',
          'paths',
          'selector',
          'wire-select',
          'program-counter',
          'instruction-register',
          'instruction-label',
          'registers',
          'alu',
          'wire-zero',
          'zero-label',
          'wire-operation',
          'operation-label',
          'control-signals',
          'clock',
          'wire-clock',
          'clock-label',
          'caches',
          'storage-contents'
        ],
        arriving: [
          'core-name',
          'firmware-instructions',
          'memory-border',
          'storage-disk',
          'storage-files'
        ]
      })
    )
  ]
});
