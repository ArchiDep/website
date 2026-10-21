// What the definition of a machine diagram imports: the core, and the actions
// of a machine stepping through a program.
export { becoming, diagram, drawingOf, START, step, teardown } from '..';
export type { Action, Becoming, DiagramDefinition, Step } from '..';

export {
  fills,
  focusOn,
  grows,
  lit,
  live,
  reads,
  tick,
  value,
  walks,
  walksAt,
  works,
  writes
} from './actions';
export type { Value } from './actions';
