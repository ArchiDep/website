declare module '*.html' {
  const value: string;
  export default value;
}

/**
 * The slim build of jQuery, typed as loosely as its one consumer needs.
 *
 * It ships no types of its own, and `@types/jquery` describes the full build,
 * so this says outright what would otherwise be inferred silently. The element
 * type parameter is declared because the caller passes one; nothing here uses
 * it, so what comes back stays `any`.
 *
 * Only `src/assets/git-memoir/git-memoir-controller.ts` uses it, and that file
 * is slated to be replaced.
 */
declare module 'jquery/dist/jquery.slim' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  type JQueryLike = any;

  function $<TElement = HTMLElement>(
    selector?: unknown,
    context?: unknown
  ): JQueryLike;

  export default $;
}
