import type { Element } from '@xmldom/xmldom';

import { Builder, type DiagramDefinition } from './builder';
import {
  byId,
  childElements,
  create,
  descendants,
  insertAfter,
  parseSvg,
  removeComments,
  rootOf,
  serialize
} from './svg';

/**
 * The parts every diagram shares, copied into each from the shared file so
 * that a diagram stays readable on its own, in Inkscape or downloaded: its
 * look, its arrowheads and its legend.
 */
const SHARED_IDS = ['diagram-styles', 'diagram-defs', 'legend'] as const;

/**
 * A diagram's file with the shared parts copied into it. Only their contents
 * are replaced: where the legend sits, given by its own `transform`, is the
 * diagram's.
 */
export function sync(source: string, shared: string, file: string): string {
  const doc = parseSvg(source, file);
  const sharedDoc = parseSvg(shared, 'shared.svg');

  for (const id of SHARED_IDS) {
    const from = byId(sharedDoc, id);
    const to = doc.getElementById(id);
    if (to === null) {
      throw new Error(`${file}: there is no element with the id "${id}"`);
    }

    while (to.firstChild !== null) {
      to.removeChild(to.firstChild);
    }

    for (let node = from.firstChild; node !== null; node = node.nextSibling) {
      to.appendChild(doc.importNode(node, true));
    }
  }

  const synced = serialize(doc);
  return synced.endsWith('\n') ? synced : `${synced}\n`;
}

export interface Partial {
  readonly name: string;
  readonly svg: string;
  readonly definition: DiagramDefinition;
  /**
   * The motion stylesheet.
   */
  readonly motion: string;
}

/**
 * The diagram as a page or a deck includes it: the drawing with its steps
 * added, the motion stylesheet and the captions of the steps.
 *
 * It is included in Markdown, by Liquid, and converted again in the browser in
 * a deck, so it is written to pass through all three untouched: no blank line,
 * which would end its HTML block, nothing Liquid would expand, and nothing a
 * deck would split it on.
 */
export function generate({ name, svg, definition, motion }: Partial): string {
  const file = `${name}.svg`;
  const drawing = parseSvg(svg, file);
  const doc = parseSvg(svg, file);
  const builder = new Builder(name, drawing, doc);

  definition.steps.forEach((step, index) => {
    for (const action of step.actions) {
      action(builder, index);
    }
  });

  for (const overlay of builder.overlays) {
    if (overlay.pendingLeg !== null) {
      throw new Error(
        `${file}: data set off for the middle of an edge, and never went onward`
      );
    }
  }

  const root = rootOf(doc);
  removeComments(doc);
  // Sized by whatever it is put in.
  root.removeAttribute('width');
  root.removeAttribute('height');
  describe(root);

  for (const overlay of builder.overlays) {
    root.appendChild(overlay.element);
  }

  insertAfter(
    byId(doc, 'diagram-styles'),
    create(doc, 'style', { class: 'diagram-motion' }, motion)
  );

  prefixIds(root, `diagram-${name}-`);

  const captions = [
    caption('rest', definition.captions.rest),
    caption('0', definition.captions.start),
    ...definition.steps.map((step, index) =>
      caption(`${index + 1}`, step.caption)
    )
  ].join('');

  const partial = [
    `<!-- Generated from diagrams/${name}.svg and ${name}.ts by "npm run diagrams": edit those instead. -->`,
    `<div class="diagram-figure" data-diagram="${name}">`,
    `<div class="diagram-canvas">`,
    compact(serialize(root)),
    `</div>`,
    `<template class="diagram-captions">${captions}</template>`,
    `</div>`
  ].join('\n');

  check(partial, file);
  return `${partial}\n`;
}

// Named by its title for those who cannot see it; a page's captions are its
// longer description.
function describe(root: Element): void {
  const title = childElements(root).find(child => child.localName === 'title');
  if (title === undefined || !title.textContent?.trim()) {
    throw new Error(
      'A diagram must have a <title>, which describes it to those who cannot see it'
    );
  }

  title.setAttribute('id', 'title');
  root.setAttribute('role', 'img');
  root.setAttribute('aria-labelledby', 'title');
}

function caption(step: string, html: string): string {
  return `<p data-caption="${step}">${html.replace(/\s+/gu, ' ').trim()}</p>`;
}

/**
 * Ids are prefixed with the diagram's name, so that two diagrams in one page or
 * deck do not take each other's arrowheads.
 */
function prefixIds(root: Element, prefix: string): void {
  const elements = [root, ...descendants(root)];
  const ids = new Set(
    elements.map(e => e.getAttribute('id')).filter((id): id is string => !!id)
  );

  for (const element of elements) {
    const id = element.getAttribute('id');
    if (id) {
      element.setAttribute('id', `${prefix}${id}`);
    }

    for (const attribute of Array.from(element.attributes)) {
      const value = attribute.value;
      const prefixed = value
        .replace(/url\(#([^)]+)\)/gu, (match, ref: string) =>
          ids.has(ref) ? `url(#${prefix}${ref})` : match
        )
        .replace(/^#(.+)$/u, (match, ref: string) =>
          attribute.localName === 'href' && ids.has(ref)
            ? `#${prefix}${ref}`
            : match
        );
      if (prefixed !== value) {
        element.setAttribute(attribute.name, prefixed);
      }
    }
  }

  const labelledBy = root.getAttribute('aria-labelledby');
  if (labelledBy) {
    root.setAttribute('aria-labelledby', `${prefix}${labelledBy}`);
  }
}

// Indentation and blank lines go: a blank line would end the HTML block the
// diagram is in, and a line indented by four spaces could be read as code.
function compact(markup: string): string {
  return markup
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
    .join('\n');
}

function check(partial: string, file: string): void {
  const problems: [RegExp, string][] = [
    [/\{[{%]/u, 'Liquid would expand "{{" or "{%"'],
    [/^\s*$/mu, 'a blank line would end its HTML block'],
    [
      /^(?:---|--v)/mu,
      'a deck would split a slide on a line starting with "---" or "--v"'
    ],
    [
      /^\*\*Notes:\*\*/mu,
      'a deck would start its speaker notes at "**Notes:**"'
    ],
    [/<\/textarea/iu, 'a deck would end at "</textarea"']
  ];

  for (const [pattern, problem] of problems) {
    if (pattern.test(partial)) {
      throw new Error(`${file}: cannot be included, since ${problem}`);
    }
  }
}
