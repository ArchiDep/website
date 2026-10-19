// What the definition of a machine diagram imports: the core, and the actions
// of a machine stepping through a program.
export { diagram, START, step } from '..';
export type { Action, DiagramDefinition, Step } from '..';

export { annotate, focusOn, lit, live, reads, value, writes } from './actions';
export type { Value } from './actions';
