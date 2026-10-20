// The machine at boot once its processor is drawn opaque: a stack of cores,
// the buses, and the room on the right for the firmware, the memory, the
// storage and the devices. Its steps follow the boot: the processor runs the
// firmware, which has the disk controller copy the bootloader into memory,
// which has it copy the kernel, which has it copy init, each jumping to the
// next once it is copied.
import {
  diagram,
  fills,
  focusOn,
  lit,
  live,
  step,
  teardown,
  walks,
  works,
  type Action
} from '../src/diagrams/build/machine';

const cells = (program: string, count: number): string[] =>
  Array.from({ length: count }, (_, i) => `${program}-cell-${i}`);
const FIRMWARE_CELLS = cells('firmware', 14);
const BOOTLOADER_CELLS = cells('bootloader', 4);
const KERNEL_CELLS = cells('kernel', 6);
const INIT_CELLS = cells('init', 3);
// Where each program waits for the disk controller, looping on its status, or,
// for the kernel, where the processor rests until an interrupt.
const FIRMWARE_WAITS = FIRMWARE_CELLS.at(-1)!;
const BOOTLOADER_WAITS = BOOTLOADER_CELLS.at(-1)!;
const KERNEL_WAITS = KERNEL_CELLS.at(-1)!;
// The kernel's code that handles the disk controller's interrupt.
const KERNEL_HANDLER = 'kernel-cell-2';

// The connections the steps open, in the drawing's coordinates, from the part
// that gives an address or a value to the part that takes it. The processor
// fetches each instruction from the firmware, then from memory, and writes the
// command to the disk controller; the disk controller copies a program's file
// into memory itself, giving the addresses to write at, and interrupts the
// processor once it is done.
const FROM_CORE = 'M231 133 H329';
const TO_CORE = 'H291 V97 H231';
const FETCH_FIRMWARE = [`${FROM_CORE} V70 H380`, `M380 34 ${TO_CORE}`];
const FETCH_MEMORY = [`${FROM_CORE} V150 H380`, `M380 210 ${TO_CORE}`];
const REQUEST = [`${FROM_CORE} V427 H380`, 'M231 97 H291 V465 H380'];
const copying = (fileX: number): string[] => [
  'M380 427 H329 V150 H380',
  `M${fileX} 527 V511 H504 V465 H291 V210 H380`
];
// The interrupt's live wire stops short of the arrowhead into the cores, which
// is lit instead.
const INTERRUPT = ['M628 443 H656', 'M73 239 H45 V196'];

const wires = (paths: readonly string[]): Action[] =>
  paths.map(path => live(path));

// What a step is about: what gives and takes the addresses and values that
// travel, and the buses and paths they travel on. The rest is faded, the cores
// too while the disk controller copies without them, their cog turning paler.
// The bands of memory are never faded, so that a band freed is seen to go.
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
const MEMORY_BOX = ['memory', 'memory-border'];
const MEMORY = [
  ...MEMORY_BOX,
  'path-data-bus-memory',
  'path-address-bus-memory'
];
const DISK_CONTROLLER = [
  'disk-controller',
  'path-data-bus-disk-controller',
  'path-address-bus-disk-controller'
];
const STORAGE = ['storage', 'path-disk-controller-storage'];
const INTERRUPTS = [
  'wire-interrupt',
  'interrupt-label',
  'wire-interrupt-others',
  'wire-interrupt-disk-controller'
];
const focus = focusOn([
  ...BUSES,
  ...CORES,
  ...FIRMWARE,
  ...MEMORY,
  ...DISK_CONTROLLER,
  ...STORAGE,
  ...INTERRUPTS,
  'path-data-bus-device-controllers',
  'path-address-bus-device-controllers',
  'device-controllers',
  'path-device-controllers-devices',
  'devices'
]);

// A program in memory running, fetching its instructions.
const RUNNING_FROM_MEMORY = focus(...CORES, ...BUSES, ...MEMORY);
// A program asking the disk controller for a copy, from where it runs.
const asking = (...asker: string[]): Action =>
  focus(...CORES, ...BUSES, ...DISK_CONTROLLER, ...asker);
// The disk controller copying a program's file into memory.
const COPYING = focus(...STORAGE, ...DISK_CONTROLLER, ...BUSES, ...MEMORY);

export default diagram({
  captions: {
    rest:
      'The processor drawn as a stack of cores, connected by the buses to the ' +
      'firmware, the memory, the disk controller and the device controllers. ' +
      'The storage and the devices are behind their controllers, and a device ' +
      'can interrupt the processor. Once booted, the memory holds the kernel ' +
      'and init.',
    start:
      'The machine is powered on. There is no program or data in memory yet.'
  },
  steps: [
    // The firmware loads the bootloader
    step(
      'The processor starts at an address that leads to the firmware, and ' +
        'runs its instructions one after the other.',
      works(),
      walks(...FIRMWARE_CELLS),
      ...wires(FETCH_FIRMWARE),
      focus(...CORES, ...BUSES, ...FIRMWARE)
    ),
    step(
      'The firmware asks the disk controller to copy the bootloader from the ' +
        'storage into memory, by writing to the controller’s registers.',
      works(),
      lit(FIRMWARE_WAITS),
      ...wires(REQUEST),
      // The firmware too, the program that asks, but not its paths
      asking('firmware')
    ),
    step(
      'The disk controller copies the bootloader into memory over the buses, ' +
        'giving the addresses to write at itself, without the processor.',
      works(),
      lit(FIRMWARE_WAITS, 'file-bootloader'),
      ...wires(copying(622)),
      fills('band-bootloader'),
      teardown(['memory-empty']),
      COPYING
    ),
    step(
      'The processor jumps to the bootloader’s first instruction, in memory: ' +
        'it now runs the bootloader.',
      works(),
      lit('bootloader-cell-0'),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),

    // The bootloader loads the kernel
    step(
      'The bootloader runs, its instructions fetched from memory one after ' +
        'the other.',
      works(),
      walks(...BOOTLOADER_CELLS),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),
    step(
      'The bootloader asks the disk controller to copy the kernel from the ' +
        'storage into memory.',
      works(),
      lit(BOOTLOADER_WAITS),
      ...wires(REQUEST),
      asking(...MEMORY_BOX)
    ),
    step(
      'The disk controller copies the kernel into memory, while the ' +
        'bootloader waits for the copy to be done.',
      works(),
      lit(BOOTLOADER_WAITS, 'file-kernel'),
      ...wires(copying(715)),
      fills('band-kernel'),
      COPYING
    ),
    step(
      'The processor jumps to the kernel’s first instruction: it now runs the ' +
        'kernel, the core of the operating system.',
      works(),
      lit('kernel-cell-0'),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),

    // The kernel loads init
    step(
      'The kernel runs, and prepares the machine: the devices, the memory, ' +
        'the other cores, the files on the storage.',
      works(),
      walks(...KERNEL_CELLS),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),
    step(
      'The kernel frees the memory the bootloader was copied into: the ' +
        'bootloader is no longer needed.',
      works(),
      lit(KERNEL_WAITS),
      teardown(['band-bootloader']),
      // As the kernel runs, so that only the band going changes
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),
    step(
      'The kernel asks the disk controller to copy init, the first program it ' +
        'starts, from the storage into memory.',
      works(),
      lit(KERNEL_WAITS),
      ...wires(REQUEST),
      asking(...MEMORY_BOX)
    ),
    step(
      'While the disk controller copies init, the processor has nothing to ' +
        'run: the kernel stops it until the copy is done.',
      lit(KERNEL_WAITS, 'file-init'),
      ...wires(copying(785)),
      fills('band-init'),
      COPYING
    ),
    step(
      'Once done, the disk controller interrupts the processor, which jumps ' +
        'to the kernel’s code that handles it, wherever it was.',
      works(),
      lit(KERNEL_HANDLER, 'wire-interrupt-tip'),
      ...wires(INTERRUPT),
      focus(...CORES, ...INTERRUPTS, 'disk-controller', ...MEMORY_BOX)
    ),
    step(
      'The kernel jumps to init’s first instruction: the processor now runs ' +
        'init.',
      works(),
      lit('init-cell-0'),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),
    step(
      'Init runs, its instructions fetched from memory one after the other.',
      works(),
      walks(...INIT_CELLS),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    )
  ]
});
