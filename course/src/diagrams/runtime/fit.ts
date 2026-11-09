const PADDING = 16;

// The width of a character of a monospace font, in ems.
const MONOSPACE_WIDTH = 0.6;

interface Box {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

/**
 * The proportions of what the diagram shows, which a slide of its own and the
 * lightbox size it by, since CSS cannot read a view box.
 */
export function setAspect(figure: HTMLElement, svg: SVGSVGElement): void {
  const { width, height } = svg.viewBox.baseVal;
  if (width && height) {
    figure.style.setProperty('--diagram-aspect', `${width} / ${height}`);
  }
}

/**
 * The view box of what a diagram shows without its legend, which leaves a gap
 * when it is hidden: CSS cannot change the view box.
 *
 * Each shape's own box leaves out its own transform, so a box still growing in
 * is measured at its full size. A network boundary is not measured: it is drawn
 * as long as the whole diagram, legend included, and is cut where the rest
 * ends. A line typed at a prompt or into an application is hidden at rest, so
 * it has no box to measure: it is counted where it will be typed, since it can
 * be the lowest thing a step shows. Returns null if the diagram has no legend,
 * or is not rendered, as on a slide that is not shown.
 */
export function viewBoxWithoutLegend(svg: SVGSVGElement): string | null {
  if (svg.querySelector('.legend') === null) {
    return null;
  }

  let box: { x1: number; y1: number; x2: number; y2: number } | null = null;
  for (const shape of svg.querySelectorAll<SVGGraphicsElement>(
    'rect, path, line, text'
  )) {
    if (shape.closest('defs, .legend, .overlay, .boundary')) {
      continue;
    }

    let b: Box | null;
    if (shape.closest('.prompt')) {
      b = typedBox(shape);
    } else {
      try {
        b = shape.getBBox();
      } catch {
        // Firefox throws for a shape that is not rendered.
        continue;
      }
    }

    if (b === null) {
      continue;
    }

    if (!b.width && !b.height) {
      continue;
    }

    box = box
      ? {
          x1: Math.min(box.x1, b.x),
          y1: Math.min(box.y1, b.y),
          x2: Math.max(box.x2, b.x + b.width),
          y2: Math.max(box.y2, b.y + b.height)
        }
      : { x1: b.x, y1: b.y, x2: b.x + b.width, y2: b.y + b.height };
  }

  if (box === null) {
    return null;
  }

  return [
    box.x1 - PADDING,
    box.y1 - PADDING,
    box.x2 - box.x1 + 2 * PADDING,
    box.y2 - box.y1 + 2 * PADDING
  ]
    .map(n => Math.round(n))
    .join(' ');
}

/**
 * Where a typed line will be, from its position, its font size and its number
 * of characters, all of which a hidden text keeps.
 */
function typedBox(shape: SVGGraphicsElement): Box | null {
  if (!(shape instanceof SVGTextElement)) {
    return null;
  }

  const x = shape.x.baseVal.numberOfItems
    ? shape.x.baseVal.getItem(0).value
    : 0;
  const y = shape.y.baseVal.numberOfItems
    ? shape.y.baseVal.getItem(0).value
    : 0;
  const size = parseFloat(getComputedStyle(shape).fontSize) || 12;
  const line = shape.closest<SVGElement>('.prompt');
  const at = parseFloat(line?.style.getPropertyValue('--at') ?? '') || 0;
  const chars = [...(shape.textContent ?? '')].length;
  return {
    x,
    y: y - size,
    width: (at + chars) * size * MONOSPACE_WIDTH,
    height: size * 1.3
  };
}
