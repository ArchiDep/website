// Stepping through a diagram in a page, outside reveal.js. A page opens with
// the diagram fully drawn, which is what someone looking something up wants;
// the story is a button away, each step with its caption. It does what reveal
// does for a deck: marks the steps reached `visible` and the last one
// `current-fragment`, which the motion stylesheet and script key off.
import { render } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';

import { setAspect, viewBoxWithoutLegend } from './fit';
import { animate } from './motion';

export interface PageDiagramOptions {
  /**
   * Shows the diagram larger than the page can, controls included. The button
   * that calls it is only shown while the figure has the `data-enlargeable`
   * attribute, which whoever enlarges it decides.
   */
  readonly enlarge?: (figure: HTMLElement) => void;
}

/**
 * Set up every diagram of a page that is not set up yet.
 */
export function setUpPageDiagrams(
  root: ParentNode = document,
  { enlarge }: PageDiagramOptions = {}
): void {
  for (const figure of root.querySelectorAll<HTMLElement>(
    '.diagram-figure:not([data-stepper])'
  )) {
    const svg = figure.querySelector<SVGSVGElement>('svg.diagram');
    if (svg === null) {
      continue;
    }

    figure.dataset['stepper'] = '';
    setAspect(figure, svg);
    animate(svg);

    const controls = document.createElement('div');
    figure.appendChild(controls);
    render(<Stepper figure={figure} svg={svg} enlarge={enlarge} />, controls);
  }
}

interface StepperProps {
  readonly figure: HTMLElement;
  readonly svg: SVGSVGElement;
  readonly enlarge: PageDiagramOptions['enlarge'];
}

/**
 * null: fully drawn, at rest. 0: stepping, before the first step.
 */
type Step = number | null;

function Stepper({ figure, svg, enlarge }: StepperProps) {
  const fragments = [...svg.querySelectorAll('.fragment')];
  const count =
    Math.max(
      -1,
      ...fragments.map(f => Number(f.getAttribute('data-fragment-index')))
    ) + 1;
  const [step, setStep] = useState<Step>(null);
  const caption = useRef<HTMLDivElement>(null);
  const fullViewBox = useRef(svg.getAttribute('viewBox'));
  const steppingViewBox = useRef<string | null>(null);

  useEffect(() => {
    figure.classList.toggle('stepping', step !== null);

    for (const fragment of fragments) {
      const index = Number(fragment.getAttribute('data-fragment-index'));
      fragment.classList.toggle('visible', step !== null && index < step);
      fragment.classList.toggle(
        'current-fragment',
        step !== null && index === step - 1
      );
    }

    // The legend is hidden while stepping, and the gap it leaves taken away.
    if (step === null) {
      if (fullViewBox.current !== null) {
        svg.setAttribute('viewBox', fullViewBox.current);
      }
    } else {
      steppingViewBox.current ??= viewBoxWithoutLegend(svg);
      if (steppingViewBox.current !== null) {
        svg.setAttribute('viewBox', steppingViewBox.current);
      }
    }
    setAspect(figure, svg);

    // The captions are the course's own, written in the diagram's definition.
    const text = figure.querySelector<HTMLTemplateElement>(
      'template.diagram-captions'
    );
    const paragraph = text?.content.querySelector(
      `[data-caption="${step === null ? 'rest' : step}"]`
    );
    caption.current?.replaceChildren(
      ...(paragraph ? [...paragraph.cloneNode(true).childNodes] : [])
    );
  }, [step]);

  // The arrow keys step once the diagram or one of its buttons has focus, so
  // that they do not take over the page's own keys.
  useEffect(() => {
    figure.tabIndex = 0;
    figure.setAttribute(
      'aria-label',
      'Architecture diagram, which can be stepped through with the arrow keys'
    );
    const onKey = (event: KeyboardEvent): void => {
      if (count === 0) {
        return;
      }

      if (event.key === 'ArrowRight') {
        setStep(s => (s === null ? 0 : Math.min(s + 1, count)));
      } else if (event.key === 'ArrowLeft') {
        setStep(s => (s === null ? s : Math.max(s - 1, 0)));
      } else {
        return;
      }

      event.preventDefault();
    };
    figure.addEventListener('keydown', onKey);
    return () => figure.removeEventListener('keydown', onKey);
  }, []);

  // Printed fully drawn, with its legend, whatever step the reader is on.
  useEffect(() => {
    let before: Step = null;
    const beforePrint = (): void =>
      setStep(s => {
        before = s;
        return null;
      });
    const afterPrint = (): void => setStep(before);
    addEventListener('beforeprint', beforePrint);
    addEventListener('afterprint', afterPrint);
    return () => {
      removeEventListener('beforeprint', beforePrint);
      removeEventListener('afterprint', afterPrint);
    };
  }, []);

  // A button that starts or stops stepping is replaced by others, and the focus
  // would fall back to the page, where the arrow keys no longer step.
  const keepFocus = (): void => figure.focus({ preventScroll: true });

  // The caption is under the controls, so that a caption of one line or of two
  // does not move the buttons being clicked. A diagram without steps has
  // nothing to step through, only its caption.
  return (
    <>
      <div className="diagram-controls">
        {step === null ? (
          count > 0 && (
            <button
              type="button"
              className="primary"
              onClick={() => {
                setStep(0);
                keepFocus();
              }}
            >
              Step through it →
            </button>
          )
        ) : (
          <>
            <button type="button" onClick={() => setStep(0)} title="Restart">
              ↺
            </button>
            <button
              type="button"
              disabled={step === 0}
              onClick={() => setStep(Math.max(step - 1, 0))}
              title="Back (←)"
            >
              ← Back
            </button>
            <span className="counter">
              Step {step} of {count}
            </span>
            <button
              type="button"
              className="primary"
              disabled={step === count}
              onClick={() => setStep(Math.min(step + 1, count))}
              title="Next (→)"
            >
              Next →
            </button>
            <button
              type="button"
              onClick={() => {
                setStep(null);
                keepFocus();
              }}
            >
              Show all
            </button>
          </>
        )}
        {enlarge && (
          <button
            type="button"
            className="enlarge"
            onClick={() => enlarge(figure)}
            title="Show it as large as the window allows"
          >
            ⤢ Enlarge
          </button>
        )}
      </div>
      <div className="diagram-caption" aria-live="polite" ref={caption} />
    </>
  );
}
