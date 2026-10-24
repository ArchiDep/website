import type { RevealApi } from 'reveal.js';

declare global {
  interface Window {
    /**
     * The reveal.js deck of a slides page, put here by `src/assets/slides.ts`
     * so that code outside the bundle, such as the screenshot script, can drive
     * the same deck rather than build one of its own.
     */
    deck?: RevealApi;

    /**
     * The same deck under the name reveal.js's own PDF export looks for.
     */
    Reveal?: RevealApi;

    /**
     * What the dashboard's log-out control calls. It is a global because the
     * markup that calls it is rendered by the application rather than by this
     * bundle.
     */
    logOut?: () => void;
  }
}
