// Stepping through a diagram in a page, outside reveal.js. A page opens with
// the diagram fully drawn, which is what someone looking something up wants;
// the story is a button away, each step with its caption. It does what reveal
// does for a deck: marks the steps reached `visible` and the last one
// `current-fragment`, which the motion stylesheet and script key off.
import { render } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';

import { viewBoxWithoutLegend } from './fit';
import { animate } from './motion';

/**
 * Set up every diagram of a page that is not set up yet.
 */
export function setUpPageDiagrams(root: ParentNode = document): void {
  for (const figure of root.querySelectorAll<HTMLElement>(
    '.diagram-figure:not([data-stepper])'
  )) {
    const svg = figure.querySelector<SVGSVGElement>('svg.diagram');
    if (svg === null) {
      continue;
    }

    figure.dataset['stepper'] = '';
    animate(svg);

    const controls = document.createElement('div');
    figure.appendChild(controls);
    render(<Stepper figure={figure} svg={svg} />, controls);
  }
}

interface StepperProps {
  readonly figure: HTMLElement;
  readonly svg: SVGSVGElement;
}

/**
 * null: fully drawn, at rest. 0: stepping, before the first step.
 */
type Step = number | null;

function Stepper({ figure, svg }: StepperProps) {
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

  // The arrow keys step once the diagram has focus, so that they do not take
  // over the page's own keys.
  useEffect(() => {
    figure.tabIndex = 0;
    figure.setAttribute(
      'aria-label',
      'Architecture diagram, which can be stepped through with the arrow keys'
    );
    const onKey = (event: KeyboardEvent): void => {
      if (event.target !== figure) {
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

  // The caption is under the controls, so that a caption of one line or of two
  // does not move the buttons being clicked.
  return (
    <>
      <div className="diagram-controls">
        {step === null ? (
          <button type="button" className="primary" onClick={() => setStep(0)}>
            Step through it →
          </button>
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
            <button type="button" onClick={() => setStep(null)}>
              Show all
            </button>
          </>
        )}
      </div>
      <div className="diagram-caption" aria-live="polite" ref={caption} />
    </>
  );
}
