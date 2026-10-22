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

const PICTURES = 'main img:not(.emoji):not(a img)';
const DIAGRAMS = 'main .diagram-figure';

let dialog: HTMLDialogElement | undefined;
let stage: HTMLElement | undefined;
let restore: (() => void) | undefined;

/**
 * Offer the lightbox for every picture and diagram of the page. The diagrams
 * must have been set up with `enlarge` as their option, which shows their
 * button for it.
 */
export function setUpLightbox(): void {
  const pictures = [...document.querySelectorAll<HTMLImageElement>(PICTURES)];
  const figures = [...document.querySelectorAll<HTMLElement>(DIAGRAMS)];
  if (pictures.length === 0 && figures.length === 0) {
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

  // The column stays as wide while the window gets taller, or shorter.
  addEventListener('resize', () => {
    for (const element of [...pictures, ...figures]) {
      offer(element);
    }
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
  // does nothing else. Around a diagram is its canvas.
  dialog.addEventListener('click', event => {
    const target = event.target as Element;
    if (
      target === dialog ||
      target.matches(
        '.lightbox-stage, .lightbox-frame, .lightbox-picture img, .diagram-canvas'
      )
    ) {
      dialog?.close();
    }
  });

  dialog.addEventListener('close', () => {
    restore?.();
    restore = undefined;
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
  if (element.closest('dialog')) {
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
 * A drawing can be shown at any size, where a photo or a screenshot becomes
 * blurred beyond its own.
 */
function isDrawing(picture: HTMLImageElement): boolean {
  return new URL(picture.currentSrc || picture.src).pathname.endsWith('.svg');
}
