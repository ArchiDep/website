// The trace of the toy machine's program, step by step, as the diagram shows it
// and the room plays it: a small interpreter of its seven instructions runs the
// program and says, for each step, what is lit, what travels and what each
// part holds, so that the steps are right by construction.
//
// The first instruction is told in full, each phase of the cycle opening with
// its pill alone; the rest of the first pass of the loop at a medium pace; the
// second pass at a fast one, a step per phase. Every phase keeps a step of its
// own, so that the trace can be followed again at any pace.
import type { Value } from '../../src/diagrams/build/machine';
import {
  ACCUMULATOR_TO_ALU,
  ALU_TO_ACCUMULATOR,
  IR_TO_MEMORY,
  IR_TO_PC,
  PC_TO_MEMORY,
  accumulatorToCell,
  cellToAccumulator,
  cellToAlu,
  cellToInstructionRegister
} from './routes';

/** Each instruction's 4 bits of operation. */
export const OPERATIONS = {
  LOAD: 0b0001,
  ADD: 0b0010,
  SUB: 0b0011,
  STORE: 0b0100,
  JUMP: 0b0110,
  JUMPZ: 0b1000,
  HALT: 0b1111
} as const;

export type Operation = keyof typeof OPERATIONS;

/**
 * The memory as the program starts: 3 × 2 by repeated addition, its
 * instructions in cells 0 to 8, its data in 12 to 15.
 */
export const PROGRAM: readonly number[] = [
  0b0001_1110, // LOAD 14   result → acc
  0b0010_1100, // ADD 12    acc + A → acc
  0b0100_1110, // STORE 14  acc → result
  0b0001_1101, // LOAD 13   counter → acc
  0b0011_1111, // SUB 15    acc − 1 → acc
  0b0100_1101, // STORE 13  acc → counter
  0b1000_1000, // JUMPZ 8   if acc = 0, go to 8
  0b0110_0000, // JUMP 0    otherwise, back to 0
  0b1111_0000, // HALT
  0,
  0,
  0,
  3, // A
  2, // counter (B)
  0, // result
  1 // one
];

/**
 * What one step shows: the parts lit, the memory read or written, the live
 * wires, the values that change, and the parts it is about.
 */
export interface StepState {
  readonly caption: string;
  /** Whether the clock ticks as the step starts. */
  readonly tick: boolean;
  readonly lit: readonly string[];
  readonly access: 'read' | 'write' | null;
  readonly live: readonly string[];
  /** The slots whose value changes at this step, and their new value. */
  readonly values: Readonly<Record<string, Value>>;
  /**
   * The parts the step is about, the others faded; or null for a step about
   * the whole machine, nothing faded.
   */
  readonly focus: readonly string[] | null;
}

export interface Trace {
  /**
   * What the machine holds from the start of stepping, besides the memory and
   * its annotations, which the drawing shows.
   */
  readonly start: Readonly<Record<string, Value>>;
  /**
   * The program as the room reads it, before the processor runs it: its
   * instructions, then its data.
   */
  readonly reading: readonly StepState[];
  /** The processor running it, from the annotations going. */
  readonly steps: readonly StepState[];
  /** The memory once the program has halted. */
  readonly memory: readonly number[];
}

type Pace = 'full' | 'medium' | 'fast';

export const CLOCK = ['clock', 'wire-clock'];
export const MEMORY_CELLS = PROGRAM.map((_, cell) => `cell-${cell}`);
const ADDRESS_TO_MEMORY = [
  'selector',
  'wire-select',
  'path-selector-address-bus',
  'address-bus',
  'path-address-bus-memory',
  'memory',
  'wire-read-write'
];
const FROM_PC = ['program-counter', 'path-pc-selector', ...ADDRESS_TO_MEMORY];
const FROM_IR = [
  'instruction-register',
  'path-ir-selector',
  ...ADDRESS_TO_MEMORY
];
const DATA_FROM_MEMORY = [
  'memory',
  'wire-read-write',
  'path-data-bus-memory',
  'data-bus'
];
const DATA_TO_MEMORY = [
  'accumulator',
  'path-acc-bus',
  'data-bus',
  'path-data-bus-memory',
  'memory',
  'wire-read-write'
];

/** The longest a program may run before it is taken never to halt. */
const MAX_INSTRUCTIONS = 100;

/** A cell's bits, as the drawing writes them. */
export function bitsOf(word: number): string {
  const bits = word.toString(2).padStart(8, '0');
  return `${bits.slice(0, 4)} ${bits.slice(4)}`;
}

function operationOf(word: number): Operation {
  const code = word >> 4;
  const found = (Object.keys(OPERATIONS) as Operation[]).find(
    name => OPERATIONS[name] === code
  );
  if (found === undefined) {
    throw new Error(`${bitsOf(word)} is not an instruction`);
  }

  return found;
}

/** An instruction as the room reads it, such as LOAD 14. */
function instructionOf(word: number): string {
  const operation = operationOf(word);
  return operation === 'HALT' ? operation : `${operation} ${word & 0b1111}`;
}

/** The cell the program leaves its result in. */
export const RESULT = 14;

export function trace(
  program: readonly number[] = PROGRAM,
  result: number = RESULT
): Trace {
  const memory = [...program];
  let pc = 0;
  let accumulator = 0;
  let zero = false;
  let secondPass = false;
  const steps: StepState[] = [];
  // The cells the program runs as instructions, and those it uses as data.
  const instructions = new Set<number>();
  const data = new Set<number>();

  // What each slot shows, so that a step only says what it changes.
  const shown = new Map<string, Value>([['program-counter', 0]]);
  const showing = (slot: string): Value => {
    if (shown.has(slot)) {
      return shown.get(slot) ?? null;
    }

    const bits = /^bits-(\d+)$/u.exec(slot);
    return bits ? bitsOf(program[Number(bits[1])] ?? 0) : null;
  };

  const step = (
    caption: string,
    {
      tick = false,
      lit = [],
      access = null,
      live = [],
      values = {},
      focus
    }: {
      readonly tick?: boolean;
      readonly lit?: readonly string[];
      readonly access?: 'read' | 'write' | null;
      readonly live?: readonly string[];
      readonly values?: Readonly<Record<string, Value>>;
      readonly focus: readonly string[] | null;
    }
  ): void => {
    const changes: Record<string, Value> = {};
    for (const [slot, value] of Object.entries(values)) {
      if (showing(slot) !== value) {
        changes[slot] = value;
        shown.set(slot, value);
      }
    }

    steps.push({
      caption,
      tick,
      lit: [...new Set(lit)],
      access,
      live,
      values: changes,
      focus: focus === null ? null : [...new Set(focus)]
    });
  };

  for (let count = 0; ; count++) {
    if (count === MAX_INSTRUCTIONS) {
      throw new Error(
        `The program has run ${MAX_INSTRUCTIONS} instructions without halting`
      );
    }

    const at = pc;
    const word = memory[at] ?? 0;
    const operation = operationOf(word);
    const address = word & 0b1111;
    const pace: Pace = count === 0 ? 'full' : secondPass ? 'fast' : 'medium';
    const cell = `cell-${address}`;
    const decoded = {
      'decoded-operation': operation,
      'decoded-address': operation === 'HALT' ? null : String(address)
    };

    // What the instruction does, worked out before it is told.
    const before = accumulator;
    const operand = memory[address] ?? 0;
    instructions.add(at);
    if (['LOAD', 'ADD', 'SUB', 'STORE'].includes(operation)) {
      data.add(address);
    }

    pc = at + 1;
    let jumped = false;
    switch (operation) {
      case 'LOAD':
        accumulator = operand;
        break;
      case 'ADD':
        accumulator = (before + operand) & 0xff;
        zero = accumulator === 0;
        break;
      case 'SUB':
        accumulator = (before - operand) & 0xff;
        zero = accumulator === 0;
        break;
      case 'STORE':
        memory[address] = accumulator;
        break;
      case 'JUMP':
        jumped = true;
        break;
      case 'JUMPZ':
        jumped = zero;
        break;
      case 'HALT':
        break;
    }
    if (jumped) {
      pc = address;
    }

    fetchAndDecode();
    execute();

    if (jumped && address <= at) {
      secondPass = true;
    }

    if (operation === 'HALT') {
      break;
    }

    // The instruction fetched and decoded, each phase opening with its tick:
    // in full, the tick alone first; at the fast pace, each phase in one step.
    function fetchAndDecode(): void {
      const fetched = {
        'instruction-register': word,
        'decoded-operation': null,
        'decoded-address': null
      };

      if (pace === 'full') {
        step(
          'Fetch: the clock ticks, and the control unit starts fetching the ' +
            'next instruction from memory.',
          { tick: true, lit: ['step-fetch'], focus: CLOCK }
        );
        step(
          'The control unit tells the selector to let the program counter’s ' +
            `address through, and the memory to read the cell at that address, ${at}.`,
          {
            lit: ['step-fetch', 'wire-select', `cell-${at}`],
            access: 'read',
            live: [PC_TO_MEMORY],
            focus: [...FROM_PC, `cell-${at}`]
          }
        );
        step(
          `The control unit tells the memory to put the bits of cell ${at} ` +
            'on the data bus, and the instruction register to take them.',
          {
            lit: ['step-fetch', `cell-${at}`],
            access: 'read',
            live: [cellToInstructionRegister(at)],
            values: fetched,
            focus: [
              ...DATA_FROM_MEMORY,
              `cell-${at}`,
              'path-bus-ir',
              'instruction-register'
            ]
          }
        );
      } else if (pace === 'fast') {
        step(
          'Fetch: the clock ticks, and the control unit has the memory read ' +
            `cell ${at}, at the program counter’s address, into the ` +
            'instruction register, and tells the program counter to add 1.',
          // The counter's new value shows at the decode step, so that the
          // counter does not already point past the cell being read; its
          // control signal is given here, in the fetch phase it belongs to.
          {
            tick: true,
            lit: ['step-fetch', 'wire-select', 'wire-count', `cell-${at}`],
            access: 'read',
            live: [PC_TO_MEMORY, cellToInstructionRegister(at)],
            values: fetched,
            focus: [
              ...CLOCK,
              ...FROM_PC,
              'wire-count',
              ...DATA_FROM_MEMORY,
              `cell-${at}`,
              'path-bus-ir',
              'instruction-register'
            ]
          }
        );
      } else {
        step(
          'Fetch: the clock ticks, and the control unit has the memory read ' +
            `cell ${at}, at the program counter’s address, into the ` +
            'instruction register.',
          {
            tick: true,
            lit: ['step-fetch', 'wire-select', `cell-${at}`],
            access: 'read',
            live: [PC_TO_MEMORY, cellToInstructionRegister(at)],
            values: fetched,
            focus: [
              ...CLOCK,
              ...FROM_PC,
              ...DATA_FROM_MEMORY,
              `cell-${at}`,
              'path-bus-ir',
              'instruction-register'
            ]
          }
        );
      }

      if (pace === 'fast') {
        step(
          'Decode: the clock ticks, and the control unit decodes the ' +
            `instruction in the instruction register: ${instructionOf(word)}. ` +
            `The program counter has counted to ${at + 1}.`,
          {
            tick: true,
            lit: ['step-decode'],
            values: {
              ...decoded,
              [`annotation-${at}`]: instructionOf(word),
              'program-counter': at + 1
            },
            focus: [...CLOCK, 'instruction-register', 'program-counter']
          }
        );
        return;
      }

      step(
        'The control unit tells the program counter to add 1, ready for the ' +
          'next instruction.',
        {
          lit: ['step-fetch', 'wire-count'],
          values: { 'program-counter': at + 1 },
          focus: ['program-counter', 'wire-count']
        }
      );

      step(
        pace === 'full'
          ? 'Decode: the clock ticks, and the control unit starts decoding ' +
              'the instruction in the instruction register, to know what to do.'
          : 'Decode: the clock ticks, and the control unit decodes the ' +
              'instruction in the instruction register.',
        {
          tick: true,
          lit: ['step-decode'],
          focus: [...CLOCK, 'instruction-register']
        }
      );
      step(
        (operation === 'HALT'
          ? 'The instruction’s 4 bits of operation are HALT, and its 4 bits ' +
            'of address are not used'
          : `The instruction’s 4 bits of operation are ${operation}, and its ` +
            `4 bits of address ${address}`) +
          (pace === 'full'
            ? `: the bits of cell ${at} were an instruction.`
            : '.'),
        {
          lit: ['step-decode'],
          // The annotation in memory is an aside: the step is about the
          // control unit decoding the instruction register, not the cell.
          values: { ...decoded, [`annotation-${at}`]: instructionOf(word) },
          focus: ['instruction-register']
        }
      );
    }

    // The instruction carried out, its tick opening the first of its steps:
    // in full, the tick alone first, then the transfers one at a time; at the
    // fast pace, in one step.
    function execute(): void {
      let opening = pace !== 'full';
      if (pace === 'full') {
        step(
          'Execute: the clock ticks, and the control unit starts carrying ' +
            'out the instruction.',
          { tick: true, lit: ['step-execute'], focus: CLOCK }
        );
      }

      const clock = (): readonly string[] => (opening ? CLOCK : []);
      const lead = (): string =>
        opening
          ? 'Execute: the clock ticks, and the control unit'
          : 'The control unit';
      const told = (
        caption: string,
        state: Parameters<typeof step>[1]
      ): void => {
        step(caption, {
          ...state,
          tick: opening,
          focus: state.focus === null ? null : [...clock(), ...state.focus]
        });
        opening = false;
      };

      switch (operation) {
        case 'LOAD':
          if (pace === 'full') {
            told(
              'The control unit tells the selector to let the instruction’s ' +
                'address through, and the memory to read the cell at that ' +
                `address, ${address}.`,
              {
                lit: ['step-execute', 'wire-select', cell],
                access: 'read',
                live: [IR_TO_MEMORY],
                focus: [...FROM_IR, cell]
              }
            );
            told(
              `The control unit tells the memory to put the bits of cell ${address} ` +
                'on the data bus, and the accumulator to take them: the ' +
                `accumulator holds ${accumulator}.`,
              {
                lit: ['step-execute', cell],
                access: 'read',
                live: [cellToAccumulator(address)],
                values: {
                  accumulator,
                  [`annotation-${address}`]: String(operand)
                },
                focus: [
                  ...DATA_FROM_MEMORY,
                  cell,
                  'path-acc-bus',
                  'accumulator'
                ]
              }
            );
          } else {
            told(
              `${lead()} has the memory read cell ${address}, at the ` +
                'instruction’s address, into the accumulator: the accumulator ' +
                `holds ${accumulator}.`,
              {
                lit: ['step-execute', 'wire-select', cell],
                access: 'read',
                live: [IR_TO_MEMORY, cellToAccumulator(address)],
                values: {
                  accumulator,
                  [`annotation-${address}`]: String(operand)
                },
                focus: [
                  ...FROM_IR,
                  ...DATA_FROM_MEMORY,
                  cell,
                  'path-acc-bus',
                  'accumulator'
                ]
              }
            );
          }
          break;

        case 'ADD':
        case 'SUB': {
          const subtract = operation === 'SUB' ? ['wire-subtract'] : [];
          const zeroWire = zero ? ['wire-zero'] : [];
          if (pace === 'fast') {
            told(
              `${lead()} has the memory read cell ${address}, at the ` +
                'instruction’s address, and the ALU ' +
                (operation === 'ADD'
                  ? `add it to the accumulator: ${before} + ${operand}`
                  : 'subtract it from the accumulator, with the subtract ' +
                    `signal on: ${before} − ${operand}`) +
                ` = ${accumulator}, which the accumulator takes.` +
                (zero ? ' The result is 0: the ALU’s zero wire is on.' : ''),
              {
                lit: [
                  'step-execute',
                  'wire-select',
                  cell,
                  ...subtract,
                  ...zeroWire
                ],
                access: 'read',
                live: [
                  IR_TO_MEMORY,
                  cellToAlu(address),
                  ACCUMULATOR_TO_ALU,
                  ALU_TO_ACCUMULATOR
                ],
                values: {
                  [`annotation-${address}`]: String(operand),
                  accumulator
                },
                focus: [
                  ...FROM_IR,
                  ...DATA_FROM_MEMORY,
                  cell,
                  'path-bus-alu',
                  'path-acc-alu',
                  'path-alu-acc',
                  'alu',
                  'accumulator',
                  ...subtract,
                  ...zeroWire
                ]
              }
            );
            break;
          }

          told(
            `${lead()} has the memory read cell ${address}, at the ` +
              'instruction’s address, and has the ALU ' +
              (operation === 'ADD'
                ? 'add it to the accumulator.'
                : 'subtract it from the accumulator, with the subtract ' +
                  'signal on.'),
            {
              lit: ['step-execute', 'wire-select', cell, ...subtract],
              access: 'read',
              live: [IR_TO_MEMORY, cellToAlu(address), ACCUMULATOR_TO_ALU],
              values: { [`annotation-${address}`]: String(operand) },
              focus: [
                ...FROM_IR,
                ...DATA_FROM_MEMORY,
                cell,
                'path-bus-alu',
                'path-acc-alu',
                'accumulator',
                'alu',
                ...subtract
              ]
            }
          );
          told(
            `The ALU gives back ${before} ${operation === 'ADD' ? '+' : '−'} ` +
              `${operand} = ${accumulator}, and the control unit tells the ` +
              `accumulator to take it: the accumulator holds ${accumulator}.` +
              (zero ? ' The result is 0: the ALU’s zero wire is on.' : ''),
            {
              lit: ['step-execute', ...subtract, ...zeroWire],
              live: [ALU_TO_ACCUMULATOR],
              values: { accumulator },
              focus: [
                'alu',
                'path-alu-acc',
                'accumulator',
                ...subtract,
                ...zeroWire
              ]
            }
          );
          break;
        }

        case 'STORE':
          told(
            `${lead()} has the memory write the accumulator’s bits, ` +
              `${accumulator}, into cell ${address}, at the instruction’s address.`,
            {
              lit: ['step-execute', 'wire-select', cell],
              access: 'write',
              live: [IR_TO_MEMORY, accumulatorToCell(address)],
              values: {
                [`bits-${address}`]: bitsOf(accumulator),
                [`annotation-${address}`]: String(accumulator)
              },
              focus: [...FROM_IR, ...DATA_TO_MEMORY, cell]
            }
          );
          break;

        case 'JUMP':
          told(
            `${lead()} tells the program counter to take the instruction’s ` +
              `address, ${address}: the program ` +
              `${address <= at ? 'goes back' : 'goes on'} to cell ${address}.`,
            {
              lit: ['step-execute'],
              live: [IR_TO_PC],
              values: { 'program-counter': address },
              focus: ['instruction-register', 'path-ir-pc', 'program-counter']
            }
          );
          break;

        case 'JUMPZ': {
          const opened = opening ? 'Execute: the clock ticks. ' : '';
          if (jumped) {
            told(
              `${opened}The ALU’s zero wire is on, since its last result was ` +
                '0: the control unit tells the program counter to take the ' +
                `instruction’s address, ${address}.`,
              {
                lit: ['step-execute', 'wire-zero'],
                live: [IR_TO_PC],
                values: { 'program-counter': address },
                focus: [
                  'alu',
                  'wire-zero',
                  'instruction-register',
                  'path-ir-pc',
                  'program-counter'
                ]
              }
            );
          } else {
            told(
              `${opened}The ALU’s zero wire is off, since its last result was ` +
                'not 0: the control unit leaves the program counter at ' +
                `${pc}.`,
              {
                lit: ['step-execute'],
                focus: ['alu', 'wire-zero', 'program-counter']
              }
            );
          }
          break;
        }

        case 'HALT':
          told(
            opening
              ? 'Execute: the clock ticks a last time, and the control unit ' +
                  'stops it, since the program is done.'
              : 'The control unit stops the clock, since the program is done.',
            { lit: ['step-execute'], focus: [] }
          );
          break;
      }
    }
  }

  // The end, a step of its own: the machine shown whole, nothing lit but the
  // result, the memory as the program leaves it.
  step(
    'The program is done, and the machine has stopped: cell ' +
      `${result} holds its result, ${memory[result] ?? 0}.`,
    { lit: [`cell-${result}`], focus: null }
  );

  // The program as the room reads it, which only the trace knows: where its
  // instructions are, then its data, in the same memory, the memory in focus.
  // Before the trace, the annotations go, since the processor knows none of
  // it. Each comes back when the processor first uses its cell.
  const sorted = (cells: Set<number>): number[] =>
    [...cells].sort((a, b) => a - b);
  const cellsOf = (cells: Set<number>): string[] =>
    sorted(cells).map(cell => `cell-${cell}`);
  const used = new Set([...instructions, ...data]);
  const quiet = { tick: false, access: null, live: [] } as const;
  const inMemory = ['memory', ...MEMORY_CELLS];
  const reading: StepState[] = [
    {
      caption: `${capitalized(cellsNamed(instructions))} hold the program: its instructions, one per cell.`,
      ...quiet,
      lit: cellsOf(instructions),
      values: {},
      focus: inMemory
    },
    {
      caption:
        `${capitalized(cellsNamed(data))} hold its data, the numbers it ` +
        'works on, in the same memory as its instructions.',
      ...quiet,
      lit: cellsOf(data),
      values: {},
      focus: inMemory
    }
  ];
  steps.unshift({
    caption:
      'The processor knows none of this: to it, the memory holds only ' +
      'bits. A cell is an instruction or a number only once the processor ' +
      'uses it as one.',
    ...quiet,
    lit: [],
    values: Object.fromEntries(
      sorted(used).map(cell => [`annotation-${cell}`, null])
    ),
    focus: ['memory', ...cellsOf(used)]
  });

  return { start: { 'program-counter': 0 }, reading, steps, memory };
}

/** Cells as a caption names them, such as "cells 0 to 8" or "cells 3 and 5". */
function cellsNamed(cells: Set<number>): string {
  const ordered = [...cells].sort((a, b) => a - b);
  const first = ordered[0];
  const last = ordered.at(-1);
  if (first === undefined || last === undefined) {
    return 'no cells';
  }

  if (ordered.length === 1) {
    return `cell ${first}`;
  }

  if (last - first === ordered.length - 1) {
    return `cells ${first} to ${last}`;
  }

  return `cells ${ordered.slice(0, -1).join(', ')} and ${last}`;
}

function capitalized(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}
