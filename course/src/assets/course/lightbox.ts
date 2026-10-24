// Pictures and diagrams shown as large as the window allows. A page's column
// can be narrow beside the course menu and the headings, which suits its text
// but not what is drawn in it, whose labels then become too small to read.
//
// It is offered only where it shows something markedly larger: a screenshot no
// larger than the column already is gains nothing, nor does anything on a
// phone, where the column is the window. A picture is shown at most at its own
// size, unless it is a drawing (SVG); a diagram is a drawing, and is sized by
// its proportions. Both are sized by the stylesheet, in `lightbox.css` of the
// theme.
//
// A diagram is not copied but moved into the lightbox, controls included, so
// that it is still on the step it was on, and is moved back when it closes.
//
// A circuit is moved too, so that it keeps the inputs and the bits the reader
// has set, but not its figure: its instructions are copied beside it or below
// it, wherever leaves the circuit larger, and it gets a bar of its own. A
// circuit is drawn at most a few times its own size, beyond which a small one
// would only fill the window with its few gates.
import type { LogicDiagramElement } from 'companion-gate';

import { circuitControls } from './circuits';

/**
 * How much larger than in the page something must be shown for the lightbox to
 * be offered.
 */
const MIN_GAIN = 1.25;

/**
 * Room the lightbox keeps around what it shows, in pixels: the padding of its
 * stage, and below a diagram, its controls and a caption of a few lines. Only
 * used to decide whether to offer it; the stylesheet does the layout.
 */
const STAGE_PADDING = 32;
const DIAGRAM_CONTROLS = 160;

/**
 * The layout of a circuit, in pixels, as `lightbox.css` draws it: its card's
 * padding, its bar, the gap between it and its instructions, and their width
 * beside it. Used to decide where its instructions go, and whether to offer the
 * lightbox at all.
 */
const CIRCUIT_CARD_PADDING = 32;
const CIRCUIT_CONTROLS = 48;
const CIRCUIT_GAP = 24;
const CIRCUIT_PANEL_WIDTH = 352;

/**
 * How many times its own size a circuit is drawn at most.
 */
const MAX_CIRCUIT_SCALE = 2;

const PICTURES = 'main img:not(.emoji):not(a img)';
const DIAGRAMS = 'main .diagram-figure';
const CIRCUITS = 'main figure.circuit';

let dialog: HTMLDialogElement | undefined;
let stage: HTMLElement | undefined;
let restore: (() => void) | undefined;
let rearrange: (() => void) | undefined;

/**
 * Offer the lightbox for every picture and diagram of the page. The diagrams
 * must have been set up with `enlarge` as their option, which shows their
 * button for it.
 */
export function setUpLightbox(): void {
  const pictures = [...document.querySelectorAll<HTMLImageElement>(PICTURES)];
  const figures = [...document.querySelectorAll<HTMLElement>(DIAGRAMS)];
  const circuits = [...document.querySelectorAll<HTMLElement>(CIRCUITS)];
  if (pictures.length === 0 && figures.length === 0 && circuits.length === 0) {
    return;
  }

  const resized = new ResizeObserver(entries => {
    for (const entry of entries) {
      offer(entry.target as HTMLElement);
    }
  });

  for (const picture of pictures) {
    resized.observe(picture);
    picture.addEventListener('load', () => offer(picture));
    picture.addEventListener('click', () => {
      if (picture.dataset['enlargeable'] !== undefined) {
        enlargePicture(picture);
      }
    });
    picture.addEventListener('keydown', event => {
      if (
        picture.dataset['enlargeable'] !== undefined &&
        (event.key === 'Enter' || event.key === ' ')
      ) {
        event.preventDefault();
        enlargePicture(picture);
      }
    });
  }

  for (const figure of figures) {
    resized.observe(figure);
    // The drawing itself opens it too, but not once it is in the lightbox.
    figure.querySelector('svg.diagram')?.addEventListener('click', () => {
      if (
        figure.dataset['enlargeable'] !== undefined &&
        !figure.closest('dialog')
      ) {
        enlargeDiagram(figure);
      }
    });
  }

  // A circuit is operated by clicking it, so only its button enlarges it.
  for (const circuit of circuits) {
    resized.observe(circuit);
  }

  // The column stays as wide while the window gets taller, or shorter.
  addEventListener('resize', () => {
    for (const element of [...pictures, ...figures, ...circuits]) {
      offer(element);
    }

    rearrange?.();
  });

  // What is printed is the page, with the diagram in it.
  addEventListener('beforeprint', () => dialog?.close());
}

/**
 * Shows a diagram, controls included, as large as the window allows.
 */
export function enlargeDiagram(figure: HTMLElement): void {
  const { dialog, stage } = lightbox();
  if (dialog.open) {
    return;
  }

  // Keeps the figure's place, so that the page behind does not move.
  const placeholder = document.createElement('div');
  placeholder.style.height = `${figure.offsetHeight}px`;
  figure.replaceWith(placeholder);

  stage.replaceChildren(figure);
  restore = () => {
    placeholder.replaceWith(figure);
    figure.focus({ preventScroll: true });
  };

  dialog.showModal();
  // The arrow keys step once the figure has focus.
  figure.focus();
}

/**
 * Shows a circuit as large as the window allows, with a copy of its
 * instructions.
 */
export function enlargeCircuit(figure: HTMLElement): void {
  const { dialog, stage } = lightbox();
  const diagram = figure.querySelector<LogicDiagramElement>('logic-diagram');
  const box = diagram && circuitBox(diagram);
  if (dialog.open || !diagram || !box) {
    return;
  }

  const shown = document.createElement('figure');
  shown.className = 'lightbox-circuit';
  shown.style.setProperty('--circuit-aspect', `${box.width / box.height}`);
  shown.style.setProperty(
    '--circuit-max-width',
    `${box.width * MAX_CIRCUIT_SCALE}px`
  );

  const card = document.createElement('div');
  card.className = 'lightbox-circuit-card';
  const frame = document.createElement('div');
  frame.className = 'lightbox-circuit-frame';
  frame.append(card, circuitControls(diagram));
  shown.append(frame);

  const instructions = figure.querySelector('.circuit-instructions');
  if (instructions) {
    const copy = document.createElement('div');
    copy.className = 'lightbox-circuit-instructions prose prose-lg';
    copy.append(...[...instructions.childNodes].map(n => n.cloneNode(true)));
    shown.append(copy);
  }

  // Keeps the circuit's place, so that the page behind does not move. It is
  // put in the lightbox in the same task as it is taken out, which is what
  // keeps its state. The widest its tag lets the page draw it does not apply
  // there.
  const placeholder = document.createElement('div');
  placeholder.style.height = `${diagram.offsetHeight}px`;
  const maxWidth = diagram.style.maxWidth;
  diagram.replaceWith(placeholder);
  diagram.style.maxWidth = '';
  card.append(diagram);
  stage.replaceChildren(shown);

  restore = () => {
    diagram.style.maxWidth = maxWidth;
    placeholder.replaceWith(diagram);
    figure
      .querySelector<HTMLElement>('.circuit-controls .enlarge')
      ?.focus({ preventScroll: true });
  };

  dialog.showModal();
  rearrange = () => arrangeCircuit(shown, box);
  rearrange();
}

/**
 * Puts a circuit's instructions beside it or below it, wherever leaves the
 * circuit larger. How tall they are below it is measured, since it depends on
 * what they say.
 */
function arrangeCircuit(shown: HTMLElement, box: DOMRect): void {
  const instructions = shown.querySelector<HTMLElement>(
    '.lightbox-circuit-instructions'
  );
  if (!instructions) {
    shown.dataset['layout'] = 'alone';
    return;
  }

  shown.dataset['layout'] = 'below';
  const below = circuitWidth(box, 0, instructions.offsetHeight + CIRCUIT_GAP);
  const beside = circuitWidth(box, CIRCUIT_PANEL_WIDTH + CIRCUIT_GAP, 0);
  shown.dataset['layout'] = beside > below ? 'side' : 'below';
}

function enlargePicture(picture: HTMLImageElement): void {
  const { dialog, stage } = lightbox();
  if (dialog.open) {
    return;
  }

  const figure = document.createElement('figure');
  figure.className = 'lightbox-picture';

  const frame = document.createElement('div');
  frame.className = 'lightbox-frame';
  const copy = document.createElement('img');
  copy.src = picture.currentSrc || picture.src;
  copy.alt = picture.alt;
  copy.style.setProperty(
    '--picture-aspect',
    `${picture.naturalWidth} / ${picture.naturalHeight}`
  );
  if (!isDrawing(picture)) {
    copy.style.setProperty('--picture-width', `${picture.naturalWidth}px`);
  }
  frame.append(copy);
  figure.append(frame);

  if (picture.alt.trim() !== '') {
    const caption = document.createElement('figcaption');
    caption.textContent = picture.alt;
    figure.append(caption);
  }

  stage.replaceChildren(figure);
  restore = () => picture.focus({ preventScroll: true });
  dialog.showModal();
}

/**
 * The lightbox, made the first time it is needed.
 */
function lightbox(): {
  readonly dialog: HTMLDialogElement;
  readonly stage: HTMLElement;
} {
  if (dialog !== undefined && stage !== undefined) {
    return { dialog, stage };
  }

  dialog = document.createElement('dialog');
  dialog.className = 'lightbox';
  dialog.setAttribute('aria-label', 'Enlarged view');

  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'lightbox-close';
  close.title = 'Close (Esc)';
  close.setAttribute('aria-label', 'Close');
  close.textContent = '✕';
  close.addEventListener('click', () => dialog?.close());

  stage = document.createElement('div');
  stage.className = 'lightbox-stage';

  dialog.append(close, stage);
  document.body.append(dialog);

  // A click anywhere but on what is shown closes it, or on a picture, which
  // does nothing else. Around a diagram is its canvas, and around a circuit,
  // its frame.
  dialog.addEventListener('click', event => {
    const target = event.target as Element;
    if (
      target === dialog ||
      target.matches(
        '.lightbox-stage, .lightbox-frame, .lightbox-picture img, .diagram-canvas, .lightbox-circuit, .lightbox-circuit-frame'
      )
    ) {
      dialog?.close();
    }
  });

  dialog.addEventListener('close', () => {
    restore?.();
    restore = undefined;
    rearrange = undefined;
    stage?.replaceChildren();
  });

  return { dialog, stage };
}

/**
 * Says whether the lightbox would show an element markedly larger than the
 * page does, with the `data-enlargeable` attribute, which the stylesheet shows
 * it can be by. A picture that can be is also made reachable by keyboard.
 */
function offer(element: HTMLElement): void {
  // A circuit that is in the lightbox has left its figure for a while.
  if (
    element.closest('dialog') ||
    (element.matches(CIRCUITS) && !element.querySelector('logic-diagram'))
  ) {
    return;
  }

  const enlargeable = gain(element) >= MIN_GAIN;
  element.toggleAttribute('data-enlargeable', enlargeable);

  if (element instanceof HTMLImageElement) {
    if (enlargeable) {
      element.tabIndex = 0;
      element.setAttribute('role', 'button');
      element.setAttribute('aria-label', `Enlarge: ${element.alt}`);
    } else {
      element.removeAttribute('tabindex');
      element.removeAttribute('role');
      element.removeAttribute('aria-label');
    }
  }
}

/**
 * How many times wider the lightbox would show an element than the page does.
 */
function gain(element: HTMLElement): number {
  const width = innerWidth - 2 * STAGE_PADDING;
  const height = innerHeight - 2 * STAGE_PADDING;

  if (element instanceof HTMLImageElement) {
    const shown = element.getBoundingClientRect().width;
    if (!shown || !element.naturalWidth || !element.naturalHeight) {
      return 0;
    }

    const aspect = element.naturalWidth / element.naturalHeight;
    const own = isDrawing(element) ? Infinity : element.naturalWidth;
    return Math.min(own, width, height * aspect) / shown;
  }

  const diagram = element.querySelector<LogicDiagramElement>('logic-diagram');
  if (diagram) {
    const box = circuitBox(diagram);
    const shown = diagram.getBoundingClientRect().width;
    if (!box || !shown) {
      return 0;
    }

    // Its instructions take as much room below it as they do in the page.
    const instructions = element.querySelector<HTMLElement>(
      '.circuit-instructions'
    );
    return instructions
      ? Math.max(
          circuitWidth(box, CIRCUIT_PANEL_WIDTH + CIRCUIT_GAP, 0),
          circuitWidth(box, 0, instructions.offsetHeight + CIRCUIT_GAP)
        ) / shown
      : circuitWidth(box, 0, 0) / shown;
  }

  const svg = element.querySelector<SVGSVGElement>('svg.diagram');
  const box = svg?.viewBox.baseVal;
  const shown = svg?.getBoundingClientRect().width;
  if (!box?.width || !box.height || !shown) {
    return 0;
  }

  const aspect = box.width / box.height;
  return Math.min(width, (height - DIAGRAM_CONTROLS) * aspect) / shown;
}

/**
 * The size a circuit is drawn at, from the drawing in its shadow root, or
 * nothing while it shows a problem instead.
 */
function circuitBox(diagram: LogicDiagramElement): DOMRect | undefined {
  const box = diagram.shadowRoot?.querySelector('svg')?.viewBox.baseVal;
  return box?.width && box.height ? box : undefined;
}

/**
 * How wide the lightbox draws a circuit, given the room taken beside it and
 * below it by what is shown with it.
 */
function circuitWidth(box: DOMRect, beside: number, below: number): number {
  const width = innerWidth - 2 * STAGE_PADDING - beside - CIRCUIT_CARD_PADDING;
  const height =
    innerHeight -
    2 * STAGE_PADDING -
    below -
    CIRCUIT_CONTROLS -
    CIRCUIT_CARD_PADDING;
  return Math.min(
    width,
    height * (box.width / box.height),
    box.width * MAX_CIRCUIT_SCALE
  );
}

/**
 * A drawing can be shown at any size, where a photo or a screenshot becomes
 * blurred beyond its own.
 */
function isDrawing(picture: HTMLImageElement): boolean {
  return new URL(picture.currentSrc || picture.src).pathname.endsWith('.svg');
}
