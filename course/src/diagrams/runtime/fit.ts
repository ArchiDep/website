const PADDING = 16;

/**
 * The view box of what a diagram shows without its legend, which leaves a gap
 * when it is hidden: CSS cannot change the view box.
 *
 * Each shape's own box leaves out its own transform, so a box still growing in
 * is measured at its full size. A network boundary is not measured: it is drawn
 * as long as the whole diagram, legend included, and is cut where the rest
 * ends. Returns null if the diagram is not rendered, as on a slide that is not
 * shown.
 */
export function viewBoxWithoutLegend(svg: SVGSVGElement): string | null {
  let box: { x1: number; y1: number; x2: number; y2: number } | null = null;
  for (const shape of svg.querySelectorAll<SVGGraphicsElement>(
    'rect, path, line, text'
  )) {
    if (shape.closest('defs, .legend, .overlay, .prompt, .boundary')) {
      continue;
    }

    let b: DOMRect;
    try {
      b = shape.getBBox();
    } catch {
      // Firefox throws for a shape that is not rendered.
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
