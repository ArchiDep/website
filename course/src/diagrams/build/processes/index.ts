// What the definition of an architecture diagram imports: the core, and the
// actions of processes, connections and data.
export { diagram, show, step, teardown } from '..';
export type { Action, DiagramDefinition, Step } from '..';

export {
  child,
  connect,
  data,
  fold,
  handOver,
  pulse,
  shortLived,
  spawned,
  typedInto,
  waiting
} from './actions';
export type { DataOptions, SpawnOptions, Trip, Wait } from './actions';
export { ARRIVED, launched, typing } from './timing';
