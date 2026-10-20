// The machine at boot once its processor is drawn opaque: a stack of cores,
// the buses, and the room on the right for the firmware, the memory, the
// storage and the devices. Its steps follow the boot: the processor runs the
// firmware, which has the disk controller copy the bootloader into memory,
// then jumps to it.
import {
  diagram,
  fills,
  focusOn,
  lit,
  live,
  step,
  teardown,
  walks,
  works
} from '../src/diagrams/build/machine';

const INSTRUCTIONS = Array.from({ length: 14 }, (_, i) => `firmware-cell-${i}`);
const WAITING = INSTRUCTIONS.at(-1)!;

// The connections the steps open, in the drawing's coordinates, from the part
// that gives an address or a value to the part that takes it. The processor
// fetches each instruction from the firmware, then from memory, and writes the
// command to the disk controller; the disk controller copies the bootloader's
// file into memory itself, giving the addresses to write at.
const FROM_CORE = 'M231 133 H329';
const TO_CORE = 'H291 V97 H231';
const FETCH_FIRMWARE = [`${FROM_CORE} V70 H380`, `M380 34 ${TO_CORE}`];
const FETCH_MEMORY = [`${FROM_CORE} V150 H380`, `M380 210 ${TO_CORE}`];
const REQUEST = [`${FROM_CORE} V427 H380`, 'M231 97 H291 V465 H380'];
const COPY = [
  'M380 427 H329 V150 H380',
  'M622 527 V511 H504 V465 H291 V210 H380'
];

// What a step is about: what gives and takes the addresses and values that
// travel, and the buses and paths they travel on. The rest is faded, the cores
// too while the disk controller copies without them, their cog turning paler.
const BUSES = ['data-bus', 'address-bus', 'address-bus-label'];
const CORES = [
  'cores',
  'path-processor-address-bus',
  'path-processor-data-bus'
];
const FIRMWARE = [
  'firmware',
  'path-data-bus-firmware',
  'path-address-bus-firmware'
];
const MEMORY = [
  'memory',
  'memory-border',
  'path-data-bus-memory',
  'path-address-bus-memory'
];
const DISK_CONTROLLER = [
  'disk-controller',
  'path-data-bus-disk-controller',
  'path-address-bus-disk-controller'
];
const STORAGE = ['storage', 'path-disk-controller-storage'];
const focus = focusOn([
  ...BUSES,
  ...CORES,
  ...FIRMWARE,
  ...MEMORY,
  ...DISK_CONTROLLER,
  ...STORAGE,
  'path-data-bus-device-controllers',
  'path-address-bus-device-controllers',
  'device-controllers',
  'path-device-controllers-devices',
  'devices',
  'wire-interrupt',
  'interrupt-label',
  'wire-interrupt-others',
  'wire-interrupt-disk-controller'
]);

export default diagram({
  captions: {
    rest:
      'The processor drawn as a stack of cores, connected by the buses to the ' +
      'firmware, the memory, the disk controller and the device controllers. ' +
      'The storage and the devices are behind their controllers, and a device ' +
      'can interrupt the processor.',
    start:
      'The machine is powered on. There is no program or data in memory yet.'
  },
  steps: [
    step(
      'The processor starts at an address that leads to the firmware, and ' +
        'runs its instructions one after the other.',
      works(),
      walks(...INSTRUCTIONS),
      ...FETCH_FIRMWARE.map(path => live(path)),
      focus(...CORES, ...BUSES, ...FIRMWARE)
    ),
    step(
      'The firmware asks the disk controller to copy the bootloader from the ' +
        'storage into memory, by writing to the controller’s registers.',
      works(),
      lit(WAITING),
      ...REQUEST.map(path => live(path)),
      // The firmware too, the program that asks, but not its paths
      focus(...CORES, ...BUSES, ...DISK_CONTROLLER, 'firmware')
    ),
    step(
      'The disk controller copies the bootloader into memory over the buses, ' +
        'giving the addresses to write at itself, without the processor.',
      works(),
      lit(WAITING, 'file-bootloader'),
      ...COPY.map(path => live(path)),
      fills('band-bootloader'),
      teardown(['memory-empty']),
      focus(...STORAGE, ...DISK_CONTROLLER, ...BUSES, ...MEMORY)
    ),
    step(
      'The processor jumps to the bootloader’s first instruction, in memory: ' +
        'it now runs the bootloader.',
      works(),
      lit('bootloader-cell-0'),
      ...FETCH_MEMORY.map(path => live(path)),
      focus(...CORES, ...BUSES, ...MEMORY)
    )
  ]
});
