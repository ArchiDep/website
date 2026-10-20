// The machine of "How a computer works" as it boots: a 64-bit processor, with
// the firmware, the memory and the disk controller on its buses, and the
// storage behind the controller. Its steps tie the figures of a shop's
// description of a computer to the parts they are about, those of the
// processor's insides first, then, once it has turned into the machine drawn on
// the next slide, `machine-boot-opaque`, where the boot is followed, the rest.
import path from 'node:path';

import {
  becoming,
  diagram,
  drawingOf,
  focusOn,
  step
} from '../src/diagrams/build/machine';

const opaque = becoming(
  drawingOf(path.join(import.meta.dirname, 'machine-boot-opaque.svg'))
);

// The processor's outline: its frame while it is detailed, never faded then,
// and the front core once it is opaque.
const FRAME = ['processor', 'processor-tab', 'processor-pill'];
const CORES = [...FRAME, 'core-name', 'cores-behind'];
const CLOCK = ['clock', 'wire-clock', 'clock-label'];
const BUSES = [
  'data-bus',
  'address-bus',
  'address-bus-label',
  'path-processor-address-bus',
  'path-processor-data-bus',
  'path-data-bus-firmware',
  'path-address-bus-firmware',
  'path-data-bus-memory',
  'path-address-bus-memory',
  'path-data-bus-disk-controller',
  'path-address-bus-disk-controller',
  'path-data-bus-device-controllers',
  'path-address-bus-device-controllers'
];
const MEMORY = [
  'memory',
  'memory-border',
  'path-data-bus-memory',
  'path-address-bus-memory'
];
const FIRMWARE = ['firmware', 'firmware-instructions'];
const STORAGE = [
  'storage',
  'storage-disk',
  'storage-files',
  'path-disk-controller-storage',
  'disk-controller',
  'path-data-bus-disk-controller',
  'path-address-bus-disk-controller'
];
const DEVICES = [
  'device-controllers',
  'path-device-controllers-devices',
  'devices'
];

// The parts a step of the description can be about; the others are faded while
// it is the current one. A step about all of them shows the whole machine
// again, so that what changes next is not mixed with a change of focus.
const PARTS = [
  ...CORES,
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
  ...CLOCK,
  'caches',
  ...BUSES,
  ...FIRMWARE,
  ...MEMORY.filter(part => !BUSES.includes(part)),
  ...STORAGE.filter(part => !BUSES.includes(part)),
  ...DEVICES,
  'wire-interrupt',
  'interrupt-label',
  'wire-interrupt-others',
  'wire-interrupt-disk-controller'
];
const focus = focusOn(PARTS);

export default diagram({
  captions: {
    rest:
      'A 64-bit processor, connected by data and address buses to the ' +
      'firmware, the memory and the disk controller. The storage is behind ' +
      'the disk controller, which the processor asks to copy from it into ' +
      'memory.',
    start:
      'A modern computer, drawn like the toy machine. The machine is powered ' +
      'on, and there is no program in memory yet.'
  },
  steps: [
    step(
      '4.5 GHz: the clock ticks 4.5 billion times a second.',
      focus(...FRAME, ...CLOCK)
    ),
    step(
      '64-bit: the registers hold 64 bits each, and the buses carry 64 bits ' +
        'at once, of data or of an address.',
      focus(...FRAME, 'program-counter', 'registers', ...BUSES)
    ),
    step(
      '32 MB of L3 cache: the largest of the processor’s caches, which keep ' +
        'copies of recently used memory. L1 and L2 belong to a core, and L3 ' +
        'is shared by all of them.',
      focus(...FRAME, 'caches')
    ),
    step('The whole processor again.', focus(...PARTS)),
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
          // Its pill, across the bottom of the core, its name centred
          'processor-tab': {
            d: 'M200 146 V164 A16 16 0 0 1 184 180 H56 A16 16 0 0 1 40 164 V146 A0 0 0 0 1 40 146 Z'
          },
          'processor-pill': { d: 'M200 146 H40 A0 0 0 0 0 40 146 V146' },
          'processor-name': { x: '120', y: '164' }
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
        'memory-empty',
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
        'interrupt-label',
        'wire-interrupt-others',
        'wire-interrupt-disk-controller'
      ]),
      opaque.arriving(
        [
          'path-address-bus-device-controllers',
          'path-data-bus-device-controllers'
        ],
        { under: 'data-bus-rail' }
      )
    ),
    step(
      '4 cores: four processors in one chip, each following a program of its ' +
        'own at the same time, sharing the buses and the memory.',
      focus(...CORES)
    ),
    step(
      '32 GB of RAM, in two sticks of 16 GB: still one memory, of about 32 ' +
        'billion cells, its addresses running on from one stick to the other. ' +
        'DDR5 6000 MHz: up to 6000 million transfers a second, which says ' +
        'nothing of how long a value takes to arrive.',
      focus(...MEMORY)
    ),
    step(
      'UEFI: the firmware, which the processor runs first at power-on, from a ' +
        'chip that is only read.',
      focus(...FIRMWARE)
    ),
    step(
      'A 2 TB NVMe SSD: the storage, where programs and files stay with the ' +
        'power off, its controller on the drive itself. PCIe 4.0 connects the ' +
        'disk controller to the rest, and up to 7450 MB/s is how fast it ' +
        'copies from the storage into memory.',
      focus(...STORAGE)
    ),
    step(
      'B650: the motherboard, which everything plugs into, and which carries ' +
        'the buses between the parts.',
      focus(...BUSES)
    ),
    step(
      'A graphics card, Wi-Fi and Ethernet: devices, each behind a controller ' +
        'whose registers the processor reaches at addresses of their own.',
      focus(...DEVICES)
    ),
    // The machine as the next slide starts it, nothing faded
    step('The whole machine again, ready to boot.', focus(...PARTS))
  ]
});
