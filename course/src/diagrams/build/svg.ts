// Helpers over the XML DOM of a diagram. The diagrams are edited in Inkscape,
// which reorders attributes and rewrites whitespace, so nothing here depends on
// how a file happens to be written: elements are found by id and read through
// their attributes.
import {
  DOMParser,
  XMLSerializer,
  type Document,
  type Element,
  type Node
} from '@xmldom/xmldom';

export const SVG_NS = 'http://www.w3.org/2000/svg';

const ELEMENT_NODE = 1;
const COMMENT_NODE = 8;

export function parseSvg(source: string, file: string): Document {
  const doc = new DOMParser({
    onError: (level, message) => {
      if (level !== 'warning') {
        throw new Error(`${file}: ${message}`);
      }
    }
  }).parseFromString(source, 'image/svg+xml');

  const root = doc.documentElement;
  if (root === null || root.localName !== 'svg') {
    throw new Error(`${file}: the root element is not <svg>`);
  }

  return doc;
}

export function serialize(node: Node): string {
  return new XMLSerializer().serializeToString(node);
}

export function rootOf(doc: Document): Element {
  const root = doc.documentElement;
  if (root === null) {
    throw new Error('The diagram has no root element');
  }

  return root;
}

export function byId(doc: Document, id: string): Element {
  const element = doc.getElementById(id);
  if (element === null) {
    throw new Error(`The diagram has no element with the id "${id}"`);
  }

  return element;
}

export function childElements(element: Element): Element[] {
  const children: Element[] = [];
  for (let node = element.firstChild; node !== null; node = node.nextSibling) {
    if (node.nodeType === ELEMENT_NODE) {
      children.push(node as Element);
    }
  }

  return children;
}

export function descendants(element: Element, localName?: string): Element[] {
  const found: Element[] = [];
  for (const child of childElements(element)) {
    if (localName === undefined || child.localName === localName) {
      found.push(child);
    }

    found.push(...descendants(child, localName));
  }

  return found;
}

export function firstDescendant(
  element: Element,
  localName: string,
  className?: string
): Element | undefined {
  return descendants(element, localName).find(
    candidate => className === undefined || hasClass(candidate, className)
  );
}

export function classesOf(element: Element): string[] {
  return (element.getAttribute('class') ?? '').split(/\s+/u).filter(Boolean);
}

export function hasClass(element: Element, className: string): boolean {
  return classesOf(element).includes(className);
}

// New classes go first, so that the classes a step adds read before the ones
// the drawing gave the element.
export function addClasses(element: Element, ...classes: string[]): void {
  const existing = classesOf(element);
  const added = classes.filter(c => !existing.includes(c));
  element.setAttribute('class', [...added, ...existing].join(' '));
}

export function number(element: Element, attribute: string): number {
  const value = Number(element.getAttribute(attribute));
  if (!Number.isFinite(value)) {
    throw new Error(
      `<${element.localName} id="${element.getAttribute('id') ?? ''}"> has no numeric "${attribute}"`
    );
  }

  return value;
}

/**
 * Merge CSS custom properties into an element's style attribute. A step's
 * timings are given to the stylesheet this way.
 */
export function setVariables(
  element: Element,
  variables: Record<string, string | number>
): void {
  const css = Object.entries(variables)
    .map(([name, value]) => `--${name}: ${value}`)
    .join('; ');
  const style = element.getAttribute('style');
  element.setAttribute('style', style ? `${css}; ${style}` : css);
}

export interface Attributes {
  readonly [name: string]: string | number | undefined;
}

export function create(
  doc: Document,
  localName: string,
  attributes: Attributes = {},
  ...children: (Element | string)[]
): Element {
  const element = doc.createElementNS(SVG_NS, localName);
  for (const [name, value] of Object.entries(attributes)) {
    if (value !== undefined) {
      element.setAttribute(name, String(value));
    }
  }

  for (const child of children) {
    element.appendChild(
      typeof child === 'string' ? doc.createTextNode(child) : child
    );
  }

  return element;
}

export function prepend(parent: Element, child: Element): void {
  parent.insertBefore(child, parent.firstChild);
}

export function insertAfter(reference: Element, element: Element): void {
  const parent = reference.parentNode;
  if (parent === null) {
    throw new Error('Cannot insert next to an element that has no parent');
  }

  parent.insertBefore(element, reference.nextSibling);
}

export function removeComments(node: Node): void {
  for (let child = node.firstChild; child !== null; ) {
    const next = child.nextSibling;
    if (child.nodeType === COMMENT_NODE) {
      node.removeChild(child);
    } else {
      removeComments(child);
    }

    child = next;
  }
}

/**
 * The process box of a process: its first rectangle.
 */
export interface Box {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

export function boxOf(doc: Document, id: string): Box {
  const rect = firstDescendant(byId(doc, id), 'rect');
  if (rect === undefined) {
    throw new Error(`"${id}" has no box`);
  }

  return {
    x: number(rect, 'x'),
    y: number(rect, 'y'),
    width: number(rect, 'width'),
    height: number(rect, 'height')
  };
}

export function commandOf(doc: Document, id: string): string {
  const text = firstDescendant(byId(doc, id), 'text', 'command');
  if (text === undefined || !text.textContent) {
    throw new Error(`"${id}" has no command to type`);
  }

  return text.textContent;
}

export function pathOf(doc: Document, id: string): Element {
  const path = firstDescendant(byId(doc, id), 'path');
  if (path === undefined) {
    throw new Error(`"${id}" has no path`);
  }

  return path;
}
