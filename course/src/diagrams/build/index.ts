// What a diagram's definition imports: the steps that reveal it, and the
// actions each step is made of. See "Architecture Diagrams" in
// `course/CONTRIBUTING.md`.
import type { Action, DiagramDefinition, Step } from './builder';

export {
  child,
  connect,
  data,
  fold,
  handOver,
  pulse,
  shortLived,
  show,
  spawned,
  teardown,
  typedInto
} from './actions';
export type { DataOptions, SpawnOptions, Trip } from './actions';
export type { Action, DiagramDefinition, Step } from './builder';
export { ARRIVED, launched, typing } from './timing';

/**
 * One click: everything it does, and what is said over it.
 */
export function step(caption: string, ...actions: Action[]): Step {
  return { caption, actions };
}

export function diagram(definition: DiagramDefinition): DiagramDefinition {
  return definition;
}
