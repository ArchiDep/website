// The machine at boot once its processor is drawn opaque: a stack of cores,
// the buses, and the room on the right for the firmware, the memory, the
// storage and the devices. Its steps follow the boot: the processor runs the
// firmware, which has the disk controller copy the bootloader into memory,
// which has it copy the kernel, which has it copy init, each jumping to the
// next once it is copied. The kernel and init make their data as they run,
// beside what was copied. Once booted, the programs init and the others start:
// on a laptop, a desktop and a browser, the keyboard and the graphics card;
// then, the same machine as a server, an SSH server, its users' sessions and
// what they run, over the network.
import {
  diagram,
  fills,
  focusOn,
  grows,
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
const KERNEL_CELLS = cells('kernel', 5);
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

// A device's interrupt, from the device controllers, its live wire stopping
// short of the arrowhead into the cores, which is lit instead.
const DEVICE_INTERRUPT = ['M45 250 V196'];
// The processor reading a device's controller, what the device sent arriving
// in it, and writing to it, for the controller to send on to the device.
const DEVICE_REGISTER = `${FROM_CORE} V272 H274`;
const FROM_DEVICE = [
  'M134 380 V340',
  DEVICE_REGISTER,
  'M239 320 H291 V97 H231'
];
const TO_DEVICE = [DEVICE_REGISTER, 'M231 97 H291 V320 H239', 'M134 340 V380'];
// Every program after init is copied from the same file, standing for all of
// them, and fills its band before its data widens beside it.
const OTHER_PROGRAMS = copying(880);
const FILL = 1.6;

const wires = (paths: readonly string[]): Action[] =>
  paths.map(path => live(path));

// What a step is about: what gives and takes the addresses and values that
// travel, and the buses and paths they travel on. The rest is faded, the cores
// too while the disk controller copies without them, their cog turning paler.
// The bands of memory are in focus whenever the memory is, so that a band freed
// is seen to go, and faded with it otherwise.
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
const BANDS = [
  'band-bootloader',
  ...[
    'kernel',
    'init',
    'desktop',
    'browser',
    'sshd',
    'session-1',
    'ls',
    'session-2',
    'sleep',
    'ps'
  ].flatMap(name => [`band-${name}`, `data-${name}`])
];
const MEMORY_BOX = ['memory', 'memory-border', ...BANDS];
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
const DEVICES = [
  'device-controllers',
  'path-data-bus-device-controllers',
  'path-address-bus-device-controllers',
  'path-device-controllers-devices',
  'devices',
  'wire-interrupt',
  'interrupt-label',
  'wire-interrupt-others'
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
// A device and the processor exchanging what it sent or is sent.
const WITH_DEVICES = focus(...CORES, ...BUSES, ...DEVICES, ...MEMORY);
// Once booted, each step draws only the transfer it is about: the processor
// fetching instructions goes without saying, its cog turning. The kernel
// freeing memory is no transfer at all.
const KERNEL_AT_WORK = focus('cores', ...MEMORY_BOX);

// A program copied into memory from the storage and run, in one step: its band
// fills, then its data widens.
const starts = (...names: string[]): Action[] => [
  lit('file-programs'),
  ...wires(OTHER_PROGRAMS),
  ...names.flatMap(name => [
    fills(`band-${name}`),
    grows(`data-${name}`, { after: FILL })
  ])
];
const freed = (...names: string[]): string[] =>
  names.flatMap(name => [`band-${name}`, `data-${name}`]);
// A program done, its memory freed by the kernel.
const ending = (name: string): Action[] => [
  works(),
  teardown(freed(name)),
  KERNEL_AT_WORK
];
// A packet arriving: the network controller interrupts the processor, and the
// kernel reads what arrived from it.
const fromNetwork = (): Action[] => [
  lit('device-network', 'wire-interrupt-tip', KERNEL_HANDLER),
  ...wires([...DEVICE_INTERRUPT, ...FROM_DEVICE])
];
// A connection closed, which arrives over the network too, and what ran in it
// freed.
const disconnecting = (...names: string[]): Action[] => [
  works(),
  ...fromNetwork(),
  teardown(freed(...names)),
  WITH_DEVICES
];

export default diagram({
  captions: {
    rest:
      'The processor drawn as a stack of cores, connected by the buses to the ' +
      'firmware, the memory, the disk controller and the device controllers. ' +
      'The storage and the devices are behind their controllers, and a device ' +
      'can interrupt the processor. Once booted, the memory holds the kernel, ' +
      'init and, on a server, the SSH server, each with its data. A program ' +
      'is an inert file in the storage; a process is a program copied into ' +
      'memory and being executed by the processor.',
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
      'The bootloader runs: the processor reads its instructions from ' +
        'memory, and runs them one after the other.',
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
      'As it runs, the kernel allocates memory for its data: its stack and ' +
        'its heap, which the file never held.',
      works(),
      lit(KERNEL_WAITS),
      grows('data-kernel'),
      // As the kernel runs, so that only its data growing changes
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),
    step(
      'The kernel frees the memory the bootloader was copied into: the ' +
        'bootloader is no longer needed.',
      works(),
      lit(KERNEL_WAITS),
      // The data's label too, once explained
      teardown(['band-bootloader', 'data-kernel-label']),
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
      'Init runs: the processor reads its instructions from memory and runs ' +
        'them one after the other, and init asks the kernel for memory for ' +
        'its data.',
      works(),
      walks(...INIT_CELLS),
      grows('data-init'),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    ),

    // A laptop
    step(
      'On a laptop, init asks the kernel to copy the desktop from storage, ' +
        'and run it: the GUI, several programs drawn as one. From now on, the ' +
        'processor fetching instructions from memory is no longer shown, but ' +
        'it still happens whenever the cog turns.',
      works(),
      ...starts('desktop'),
      COPYING
    ),
    step(
      'The user opens a browser: the desktop asks the kernel to copy it ' +
        'from storage, and run it.',
      works(),
      ...starts('browser'),
      COPYING
    ),
    step(
      'A key is pressed: the keyboard’s controller interrupts the processor, ' +
        'and the kernel hands the key to the desktop, which passes it to the ' +
        'browser.',
      works(),
      lit(
        'device-keyboard',
        'wire-interrupt-tip',
        KERNEL_HANDLER,
        'desktop-cell-0',
        'browser-cell-0'
      ),
      ...wires([...DEVICE_INTERRUPT, ...FROM_DEVICE]),
      WITH_DEVICES
    ),
    step(
      'The browser draws the letter, and the desktop sends the new picture of ' +
        'the screen to the graphics card.',
      works(),
      lit('browser-cell-3', 'desktop-cell-3', 'device-graphics-card'),
      ...wires(TO_DEVICE),
      WITH_DEVICES
    ),

    // The same machine as a server
    step(
      'A cloud server runs no GUI: once booted, only the kernel and init are ' +
        'in memory.',
      works(),
      teardown(freed('desktop', 'browser')),
      KERNEL_AT_WORK
    ),
    step(
      'With nothing to run, the kernel stops the processor until an interrupt ' +
        'from a device wakes it.',
      focus(...MEMORY_BOX, ...DEVICES)
    ),
    step(
      'Nobody sits in front of a cloud server: it has no keyboard and no ' +
        'graphics card.',
      teardown(['device-keyboard', 'device-graphics-card']),
      focus(...MEMORY_BOX, ...DEVICES)
    ),
    step(
      'Instead of a GUI, init asks the kernel to copy the SSH server from ' +
        'storage, and run it: it waits for connections.',
      works(),
      ...starts('sshd'),
      COPYING
    ),
    step(
      'Until a connection arrives, nothing runs: the kernel stops the ' +
        'processor again.',
      focus(...MEMORY_BOX)
    ),
    step(
      'A connection arrives: the network controller interrupts the processor, ' +
        'and the kernel hands what arrived to the SSH server.',
      works(),
      ...fromNetwork(),
      WITH_DEVICES
    ),
    step(
      'The SSH server asks the kernel to copy an SSH session and a shell from ' +
        'storage, and run them: two programs drawn as one.',
      works(),
      ...starts('session-1'),
      COPYING
    ),
    step(
      'The user types ls: the keystrokes arrive over the network, and the ' +
        'kernel hands them to the SSH session, which passes them to the shell.',
      works(),
      ...fromNetwork(),
      WITH_DEVICES
    ),
    step(
      'The shell asks the kernel to copy ls from storage, and run it: its ' +
        'output goes back over the network.',
      works(),
      ...starts('ls'),
      COPYING
    ),
    step(
      'ls is done: it ends, and the kernel frees its memory.',
      ...ending('ls')
    ),
    step(
      'A second connection arrives over the network, for another login.',
      works(),
      ...fromNetwork(),
      WITH_DEVICES
    ),
    step(
      'The SSH server starts a second SSH session and shell: the same ' +
        'programs, running twice, each with its own memory.',
      works(),
      ...starts('session-2'),
      COPYING
    ),
    step(
      'The first shell runs sleep, which waits without using the processor.',
      works(),
      ...starts('sleep'),
      COPYING
    ),
    step(
      'The second shell runs ps, which asks the kernel for every process ' +
        'running and prints them, over the network.',
      works(),
      ...starts('ps'),
      COPYING
    ),
    step(
      'ps is done: it ends, and the kernel frees its memory.',
      ...ending('ps')
    ),
    step(
      'The second user disconnects: their session and shell end, and the ' +
        'kernel frees their memory.',
      ...disconnecting('session-2')
    ),
    step(
      'sleep is done waiting: it ends, and the kernel frees its memory.',
      ...ending('sleep')
    ),
    step(
      'The first user disconnects too. Only the SSH server is left, waiting ' +
        'for the next connection.',
      ...disconnecting('session-1')
    ),
    step(
      'The server is idle again: until the next connection, the kernel stops ' +
        'the processor.',
      focus(...MEMORY_BOX)
    ),

    // What to remember
    step(
      'A program is a file: inert bytes in the storage, such as init, until ' +
        'the kernel copies it into memory.',
      lit('file-init'),
      focus(...STORAGE)
    ),
    step(
      'A process is a program copied into memory and being executed: the ' +
        'processor reads a program’s instructions from memory, and runs them one ' +
        'after the other.',
      works(),
      lit('init-cell-1'),
      ...wires(FETCH_MEMORY),
      RUNNING_FROM_MEMORY
    )
  ]
});
