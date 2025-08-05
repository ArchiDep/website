import $ from 'jquery/dist/jquery.slim';
import tippy, { Instance } from 'tippy.js';
import { Drawer, Memoir, NarrationDrawOptions } from 'git-memoir';
import Reveal from 'reveal.js';
import { O, pipe } from '@mobily/ts-belt';

type Mode = 'autoplay' | 'manual' | 'visualization';

const MODES: readonly Mode[] = [
  // The memoir starts in its initial state and starts drawing 1.5 seconds after the slide is displayed.
  //
  // If the memoir is not drawn and not currently drawing when entering this mode,
  // drawing automatically starts 1 second later.
  'autoplay',
  // The memoir starts in its initial state and is only drawn when manually clicking the play button.
  'manual',
  // The memoir starts in its end state and can be reset to its initial state by clicking the backward button,
  // or reset to its initial state and automatically drawn by clicking the play button.
  //
  // If the memoir is not drawn and not currently drawing when entering this mode,
  // it is instantly drawn to display the end state.
  'visualization'
];

const gitMemoirs: Record<string, () => Memoir> = window['gitMemoirs'] ?? {};

export class GitMemoirController {
  static start(deck: Reveal.Api) {
    let memoirsCount = this.startGitMemoirs();
    deck.on('slidechanged', () => {
      if (memoirsCount !== 0) {
        this.destroyGitMemoirs();
      }

      memoirsCount = this.startGitMemoirs();
    });
  }

  static startGitMemoirs() {
    const memoirs = $('.reveal .slides .present git-memoir');
    memoirs.each(function () {
      new GitMemoirController(this).start();
    });

    return memoirs.length;
  }

  static destroyGitMemoirs() {
    $('.reveal .slides git-memoir').each(function () {
      const memoirController = $(this).data('controller');
      if (memoirController) {
        memoirController.destroy();
      }
    });
  }

  $playButton: JQuery<HTMLButtonElement> | undefined;
  $modeButton: JQuery<HTMLButtonElement> | undefined;
  $backButton: JQuery<HTMLButtonElement> | undefined;

  readonly $element: JQuery<HTMLElement>;
  readonly name: string;
  readonly svgHeight: string;
  readonly chapter: string | undefined;
  readonly chapters: number;
  readonly controlsEnabled: boolean;
  readonly memoirFactory: () => Memoir;

  #mode: Mode;
  #started: boolean;
  #playing: boolean;
  #played: boolean;
  #drawer: Drawer | undefined;
  #drawingPromise: Promise<unknown> | undefined;
  #tooltips: Instance[] | undefined;

  constructor(element) {
    this.$element = $(element);
    this.$element.data('controller', this);

    const name = this.$element.attr('name');
    if (!name) {
      throw new Error('<git-memoir> must have a "name" attribute');
    }

    this.name = name;

    const urlParams = new URLSearchParams(window.location.search);
    const urlMode = pipe(
      O.fromNullable(urlParams.get('git-memoir-mode')),
      O.flatMap(value => (isMode(value) ? O.Some(value) : O.None)),
      O.toUndefined
    );
    const storedMode = pipe(
      O.fromNullable(localStorage.getItem('archidep.gitMemoirMode')),
      O.flatMap(value => (isMode(value) ? O.Some(value) : O.None)),
      O.toUndefined
    );
    this.#mode = urlMode ?? storedMode ?? 'autoplay';

    const svgHeight = this.$element.attr('svg-height');
    if (!svgHeight) {
      throw new Error('<git-memoir> must have an "svg-height" attribute');
    }

    this.svgHeight = svgHeight;

    this.chapter = this.$element.attr('chapter');

    this.chapters = parseInt(this.$element.attr('chapters') ?? '1', 10);
    if (isNaN(this.chapters) || this.chapters <= 0) {
      this.chapters = 1;
    }

    const controlsAttr = this.$element.attr('controls');
    this.controlsEnabled =
      !controlsAttr || /^(1|y|yes|t|true)$/i.exec(controlsAttr) !== null;

    const memoirFactory = gitMemoirs[this.name];
    if (!memoirFactory) {
      throw new Error(
        `No memoir found named "${this.name}"; assign a factory function to "window.gitMemoirs.${this.name}"`
      );
    } else if (typeof memoirFactory != 'function') {
      throw new Error(
        `Memoir named "${this.name}" must be a function, got ${typeof memoirFactory}`
      );
    }

    this.memoirFactory = memoirFactory;
  }

  start() {
    if (this.#started) {
      this.destroy();
    }

    this.#started = true;
    this.#playing = false;
    this.#played = false;

    const memoir = this.memoirFactory();

    const $svg = $(
      document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    )
      .attr('width', '100%')
      .attr('height', this.svgHeight)
      .appendTo(this.$element);

    if (this.controlsEnabled) {
      const $controls = $('<div class="memoir-controls" />').appendTo(
        this.$element
      );
      this.$playButton = $<HTMLButtonElement>(
        '<button type="button" class="play tooltip" title="Play"><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="M4.5 5.653c0-1.427 1.529-2.33 2.779-1.643l11.54 6.347c1.295.712 1.295 2.573 0 3.286L7.28 19.99c-1.25.687-2.779-.217-2.779-1.643z" clip-rule="evenodd"/></svg></button>'
      ).appendTo($controls);

      this.$modeButton = $<HTMLButtonElement>(
        '<button type="button" class="mode tooltip" data-dynamictitle="true"><span class="icon" /></button>'
      );
      if (isLocalStorageAvailable()) {
        this.$modeButton.appendTo($controls);
      }

      this.$backButton = $<HTMLButtonElement>(
        '<button type="button" class="back tooltip" title="Back"><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="currentColor" d="M9.195 18.44c1.25.714 2.805-.189 2.805-1.629v-2.34l6.945 3.968c1.25.715 2.805-.188 2.805-1.628V8.69c0-1.44-1.555-2.343-2.805-1.628L12 11.029v-2.34c0-1.44-1.555-2.343-2.805-1.628l-7.108 4.061c-1.26.72-1.26 2.536 0 3.256z"/></svg></button>"'
      ).appendTo($controls);

      this.updateControls();
      this.createTooltips();
    }

    this.#drawer = new Drawer(memoir, {
      svg: $svg[0]
    });
    //this.drawer.setDebugging(true);

    const drawingPromise = this.drawInitialStep();

    if (this.controlsEnabled && this.#mode === 'autoplay') {
      drawingPromise.then(() => {
        this.drawNextSteps();
      });
    }

    if (this.controlsEnabled) {
      this.$playButton?.on('click', () => this.drawNextSteps());
      this.$modeButton?.on('click', () => this.cycleMode());
      this.$backButton?.on('click', () => this.undraw());
    }
  }

  drawInitialStep() {
    const drawOptions: NarrationDrawOptions = {
      immediate: true,
      stepDuration: 0
    };

    if (
      !this.#played &&
      (this.#mode === 'visualization' || !this.controlsEnabled)
    ) {
      drawOptions.chapter = this.chapter ?? 'n/a';
      this.#played = true;
    } else {
      this.#played = false;
      drawOptions.until = this.chapter ?? 'n/a';
    }

    const done = () => {
      this.updateControls();
    };

    return this.draw(drawOptions).then(done, done);
  }

  drawNextSteps(instant?: boolean) {
    if (
      (this.$playButton && this.$playButton.is('.disabled')) ||
      this.#playing
    ) {
      return;
    }

    this.#playing = true;
    this.updateControls();

    if (this.#played) {
      this.#drawer?.clear();
      this.drawInitialStep();
    }

    const done = () => {
      this.#played = true;
      this.updateControls();
    };

    const drawOptions = {
      immediate: !!instant,
      chapters: 1,
      initialDelay: instant ? 0 : 1000,
      stepDuration: instant ? 0 : 1000
    };

    this.draw(drawOptions).then(done, done);
  }

  undraw() {
    if (this.$backButton?.is('.disabled') || this.#playing || !this.#played) {
      return;
    }

    this.#drawer?.clear();
    return this.drawInitialStep();
  }

  draw(options: NarrationDrawOptions) {
    const done = () => {
      this.#playing = false;
    };

    this.#drawingPromise = (this.#drawingPromise || Promise.resolve())
      .then(() => {
        this.#playing = true;
        return this.#drawer?.draw(options);
      })
      .then(done)
      .catch(err => {
        console.warn(err);
        done();
        throw err;
      });

    return this.#drawingPromise;
  }

  cycleMode() {
    const index = MODES.indexOf(this.#mode);
    this.setMode(MODES[index + 1] ?? 'autoplay');

    if (
      (this.#mode === 'autoplay' || this.#mode === 'visualization') &&
      !this.#playing &&
      !this.#played
    ) {
      this.drawNextSteps(this.#mode === 'visualization');
    }
  }

  setMode(mode: Mode) {
    this.#mode = mode;
    localStorage.setItem('archidep.gitMemoirMode', mode);
    this.updateModeButton();
  }

  updateControls() {
    if (this.controlsEnabled) {
      this.$playButton?.[this.#playing ? 'addClass' : 'removeClass'](
        'disabled'
      );
      this.$backButton?.[
        this.#playing || !this.#played ? 'addClass' : 'removeClass'
      ]('disabled');
      this.updateModeButton();
    }
  }

  updateModeButton() {
    let icon =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"><path d="M21 12a9 9 0 1 1-18 0a9 9 0 0 1 18 0"/><path d="M15.91 11.672a.375.375 0 0 1 0 .656l-5.603 3.113a.375.375 0 0 1-.557-.328V8.887c0-.286.307-.466.557-.327z"/></g></svg>';
    let title = 'Autoplay mode';

    if (this.#mode === 'manual') {
      icon =
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M14.25 9v6m-4.5 0V9M21 12a9 9 0 1 1-18 0a9 9 0 0 1 18 0"/></svg>';
      title = 'Manual mode';
    } else if (this.#mode === 'visualization') {
      icon =
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12.75L11.25 15L15 9.75M21 12a9 9 0 1 1-18 0a9 9 0 0 1 18 0"/></svg>';
      title = 'Visualization mode';
    }

    this.$modeButton?.attr('title', title);

    const $icon = this.$modeButton?.find('.icon');
    if ($icon) {
      $icon.html(icon);
    }

    this.updateModeTooltip(title);
  }

  createTooltips() {
    this.#tooltips = tippy('git-memoir .tooltip[title]', {
      hideOnClick: false,
      content(reference) {
        const title = reference.getAttribute('title');
        reference.removeAttribute('title');
        return title ?? 'n/a';
      }
    });
  }

  destroy() {
    if (this.#drawer) {
      this.#drawer.clear();
    }

    this.destroyTooltips();

    this.$element.children().remove();
  }

  destroyTooltips() {
    if (this.#tooltips) {
      destroyTooltips(this.#tooltips);
    }
  }

  updateModeTooltip(text) {
    if (!this.#tooltips) {
      return;
    }

    const modeTooltip = this.#tooltips.find(tooltip =>
      $(tooltip.reference).is('button.mode')
    );
    if (!modeTooltip) {
      return;
    }

    modeTooltip.setContent(text);
    modeTooltip.reference.removeAttribute('title');
  }
}

function destroyTooltips(tooltips) {
  if (Array.isArray(tooltips)) {
    tooltips.forEach(destroyTooltips);
  } else {
    tooltips.destroy();
  }
}

function isLocalStorageAvailable() {
  return typeof Storage != 'undefined';
}

function isMode(value: string): value is Mode {
  return MODES.includes(value as Mode);
}
