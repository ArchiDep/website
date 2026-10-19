// The core of every diagram's definition: the steps that reveal it, and the
// actions any diagram can use. A family's vocabulary adds its own and exports
// these with them, and is what a definition imports, such as `processes` for
// the architecture diagrams. See "Architecture Diagrams" in
// `course/CONTRIBUTING.md`.
import type { Action, DiagramDefinition, Step } from './builder';

export {
  copyOf,
  during,
  goneFrom,
  reveal,
  runs,
  show,
  teardown
} from './actions';
export type { Run } from './actions';
export { START } from './builder';
export type { Action, Builder, DiagramDefinition, Step } from './builder';

/**
 * One click: everything it does, and what is said over it.
 */
export function step(caption: string, ...actions: Action[]): Step {
  return { caption, actions };
}

export function diagram(definition: DiagramDefinition): DiagramDefinition {
  return definition;
}
