// Where the live wires of the machine run, in the coordinates of its drawing,
// `machine.svg`: from the part that gives a value to the part that takes it.
// `routes.test.ts` checks the coordinates they are built from against the
// drawing.

/** Where the first cell's box starts, and how far apart the cells are. */
export const CELLS = { x: 806, y: 66, height: 28, pitch: 32 } as const;
/** The column inside the memory, left of the addresses, that wires run down. */
const MEMORY_X = 750;
/** The data bus's horizontal run, along which values cross to the processor. */
const DATA_BUS_Y = 491;

/** The middle of a cell's box. */
function cellY(cell: number): number {
  return CELLS.y + cell * CELLS.pitch + CELLS.height / 2;
}

/** The gap between a cell and the next one on the side of the data bus. */
function gapY(cell: number): number {
  const top = CELLS.y + cell * CELLS.pitch;
  return cellY(cell) < DATA_BUS_Y ? top + CELLS.height + 2 : top - 2;
}

/**
 * From a cell's box to the data bus: into the gap next to the cell, on the
 * side of the bus, then down or up the memory's column.
 */
function cellToBus(cell: number): string {
  return `M${CELLS.x} ${cellY(cell)} H${CELLS.x - 5} V${gapY(cell)} H${MEMORY_X} V${DATA_BUS_Y}`;
}

/** An address from the program counter, through the selector, to the memory. */
export const PC_TO_MEMORY = 'M216 55 H476 L524 75 H738';
/** An address from the instruction register, through the selector, to the memory. */
export const IR_TO_MEMORY = 'M293 210 V95 H476 L524 75 H738';
/** An address from the instruction register to the program counter: a jump. */
export const IR_TO_PC = 'M205 210 V124';
/** The accumulator's value into the ALU, wired straight to it. */
export const ACCUMULATOR_TO_ALU = 'M330 389 V450 H560 V405 H520';
/** The ALU's result into the accumulator. */
export const ALU_TO_ACCUMULATOR = 'M440 372 H374';

/** A cell's bits into the instruction register: a fetch. */
export function cellToInstructionRegister(cell: number): string {
  return `${cellToBus(cell)} H100 V244`;
}

/** A cell's bits into the accumulator. */
export function cellToAccumulator(cell: number): string {
  return `${cellToBus(cell)} H190 V389`;
}

/** A cell's bits into the ALU, up the data bus. */
export function cellToAlu(cell: number): string {
  return `${cellToBus(cell)} H631 V341 H520`;
}

/** The accumulator's bits into a cell: a store. */
export function accumulatorToCell(cell: number): string {
  return `M190 389 V${DATA_BUS_Y} H${MEMORY_X} V${gapY(cell)} H${CELLS.x - 5} V${cellY(cell)} H${CELLS.x}`;
}
