import { CustomProperties } from '@plausible-analytics/tracker';
import Reveal from 'reveal.js';

declare global {
  interface Window {
    /**
     * The reveal.js deck of a slides page, put here by `src/assets/slides.ts`
     * so that the scripts loaded beside it, such as the Mermaid renderer, can
     * drive the same deck rather than build one of their own.
     */
    deck?: Reveal.Api;

    /**
     * The same deck under the name reveal.js's own PDF export looks for.
     */
    Reveal?: Reveal.Api;

    /**
     * What the dashboard's log-out control calls. It is a global because the
     * markup that calls it is rendered by the application rather than by this
     * bundle.
     */
    logOut?: () => void;

    /**
     * The analytics tracker, present only once its own script has loaded —
     * which it never does in a standalone build.
     */
    plausible?: (name: string, options?: { props?: CustomProperties }) => void;
  }
}
