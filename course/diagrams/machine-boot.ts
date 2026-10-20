// The machine of "How a computer works" as it boots: a 64-bit processor, with
// the firmware, the memory and the disk controller on its buses, and the
// storage behind the controller. Its last steps turn it into the machine drawn
// on the next slide, `machine-boot-opaque`, where the boot is followed.
import path from 'node:path';

import {
  becoming,
  diagram,
  drawingOf,
  step
} from '../src/diagrams/build/machine';

const opaque = becoming(
  drawingOf(path.join(import.meta.dirname, 'machine-boot-opaque.svg'))
);

export default diagram({
  captions: {
    rest:
      'A 64-bit processor, connected by data and address buses to the ' +
      'firmware, the memory and the disk controller. The storage is behind ' +
      'the disk controller, which the processor asks to copy from it into ' +
      'memory.',
    start: 'The machine is powered on. There is no program in memory yet.'
  },
  steps: [
    step(
      'From now on, the processor is drawn as a box: what is inside it is no ' +
        'longer shown.',
      opaque.leaving(
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
        // Its connections to the buses, which come back once it is in place
        'path-processor-address-bus',
        'path-processor-data-bus',
        'data-bus-turn',
        // Its dashes, fading into the solid outline drawn under them
        'processor-dashes',
        'processor-pill-dashes'
      ),
      opaque.reshaped({
        processor: {
          style: 'fill: #ffffff; fill-opacity: 1; stroke-opacity: 1'
        },
        'processor-pill': { style: 'fill: none; stroke-opacity: 1' }
      })
    ),
    step(
      'The processor is drawn smaller: what follows happens outside it.',
      opaque.reshaped(
        {
          processor: { x: '40', y: '20', width: '160', height: '160' },
          // Its pill, in the corner it moves to, as wide as before
          'processor-tab': {
            d: 'M200 146 V164 A16 16 0 0 1 184 180 H76 V162 A16 16 0 0 1 92 146 Z'
          },
          'processor-pill': { d: 'M200 146 H92 A16 16 0 0 0 76 162 V180' },
          'processor-name': { x: '138', y: '164' }
        },
        { unseen: ['processor-name'] }
      )
    ),
    step(
      'It is one core of the processor, which has several, each following a ' +
        'program of its own.',
      opaque.leaving('processor-name'),
      opaque.into('processor', 'processor-tab', 'processor-pill'),
      opaque.arriving(['core-name']),
      opaque.arriving(['cores-behind'], { under: 'processor' })
    ),
    step(
      'The firmware, the memory and the storage take the room the processor ' +
        'leaves.',
      opaque.leaving('storage-contents'),
      opaque.into(
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
      ),
      opaque.arriving([
        'firmware-instructions',
        'memory-border',
        'storage-disk',
        'storage-files'
      ]),
      // Reconnected, under the buses as drawn
      opaque.arriving(
        ['path-processor-address-bus', 'path-processor-data-bus'],
        { under: 'data-bus-rail' }
      )
    ),
    step(
      'Everything else is a device behind a controller on the buses, which can ' +
        'interrupt the processor when something must be handled.',
      opaque.arriving([
        'path-device-controllers-devices',
        'device-controllers',
        'devices',
        'wire-interrupt',
        'interrupt-label'
      ]),
      opaque.arriving(
        [
          'path-address-bus-device-controllers',
          'path-data-bus-device-controllers'
        ],
        { under: 'data-bus-rail' }
      )
    )
  ]
});
