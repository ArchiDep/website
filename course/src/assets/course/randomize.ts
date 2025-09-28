import { effect, signal } from '@preact/signals';
import { Chance } from 'chance';

import log from '../logging';
import { shuffle } from 'lodash-es';

const logger = log.getLogger('randomizer');
const randomizerKey = Symbol('archidep-randomizer');
const chance = new Chance();

class Randomizer {
  static for(element: HTMLElement): Randomizer | undefined {
    const id = element.id;
    if (!id) {
      logger.warn(
        `Cannot create a randomizer for an element with no ID`,
        element
      );
      return undefined;
    }

    const regexp = element.dataset['regexp'];
    if (!regexp) {
      logger.warn(
        `Cannot create a randomizer for element with ID ${id} because it has no data-regexp attribute`,
        element
      );
      return undefined;
    } else {
      try {
        new RegExp(regexp);
      } catch (e) {
        logger.warn(
          `Cannot create a randomizer for element with ID ${id} because its data-regexp attribute is not a valid regular expression: ${e}`,
          element
        );
        return undefined;
      }
    }

    const template = element.dataset['template'];
    if (!template) {
      logger.warn(
        `Cannot create a randomizer for element with ID ${id} because it has no data-template attribute`,
        element
      );
      return undefined;
    }

    const tooltipEnabled = element.dataset['tooltip'] ?? 'true';
    if (tooltipEnabled !== 'false' && tooltipEnabled !== 'true') {
      logger.warn(
        `Cannot create a randomizer for element with ID ${id} because its data-tooltip attribute is not "true" or "false" (got "${tooltipEnabled}")`,
        element
      );
      return undefined;
    }

    const codeElement =
      document.querySelector<HTMLElement>(`#${id} + * code`) ?? undefined;
    if (!codeElement) {
      logger.warn(
        `Cannot create a randomizer for element with ID ${id} because no code element was found under its next sibiling`,
        element
      );
      return undefined;
    }

    const randomizer = new Randomizer(
      codeElement,
      new RegExp(regexp, 'i'),
      template
    );

    if (tooltipEnabled === 'true') {
      const parent = codeElement.parentElement?.parentElement?.parentElement;
      if (parent) {
        parent.classList.add('tooltip', 'tooltip-accent', 'block');
        parent.dataset['tip'] = 'Remember to change the values!';
      }
    }

    codeElement[randomizerKey] = randomizer;

    return randomizer;
  }

  #textNodes: readonly [ChildNode, string, Record<string, string>][];

  constructor(
    readonly codeElement: HTMLElement,
    private readonly regexp: RegExp,
    private readonly template: string
  ) {
    this.#textNodes = findChildNodesMatching(codeElement, regexp);
    this.initialize();
  }

  initialize(): void {
    this.#textNodes = this.#textNodes.map(
      ([node, originalText, replacements]) => {
        const username =
          replacements['username'] === 'jde'
            ? 'jde'
            : this.#randomizeUsername(replacements['username']);
        const ipAddress = this.#randomizeIpAddress(replacements['ipAddress']);
        const domain = this.#randomizeDomain(replacements['domain']);
        replacements['ipAddress'] = ipAddress;
        replacements['username'] = username;
        replacements['domain'] = domain;

        const text = this.template
          .replace('<username>', username)
          .replace('<ipAddress>', ipAddress)
          .replace('<domain>', domain);

        node.textContent = originalText.replace(this.regexp, text);

        return [node, originalText, replacements] as const;
      }
    );
  }

  randomize(): void {
    this.#textNodes = this.#textNodes.map(
      ([node, originalText, replacements]) => {
        const part = shuffle(
          ['username', 'ipAddress', 'domain'].filter(
            part => part in replacements
          )
        )[0];

        if (part === 'username') {
          replacements['username'] = this.#randomizeUsername(
            replacements['username']
          );
        } else if (part === 'ipAddress') {
          replacements['ipAddress'] = this.#randomizeIpAddress(
            replacements['ipAddress']
          );
        } else if (part === 'domain') {
          replacements['domain'] = this.#randomizeDomain(
            replacements['domain']
          );
        }

        const username = replacements['username'] ?? this.#randomizeUsername();
        const ipAddress =
          replacements['ipAddress'] ?? this.#randomizeIpAddress();
        const domain = replacements['domain'] ?? this.#randomizeDomain();
        replacements['username'] = username;
        replacements['ipAddress'] = ipAddress;
        replacements['domain'] = domain;

        const text = this.template
          .replace('<username>', username)
          .replace('<ipAddress>', ipAddress)
          .replace('<domain>', domain);

        node.textContent = originalText.replace(this.regexp, text);

        return [node, originalText, replacements] as const;
      }
    );
  }

  #randomizeUsername(previousUsername?: string): string {
    if (previousUsername === undefined) {
      return 'jde';
    } else if (previousUsername === 'jde') {
      return `jd${randomAlphanumericChar('e')}`;
    }

    const length = previousUsername.length;
    const indexToRandomize = chance.integer({
      min: length >= 2 && previousUsername.startsWith('j') ? 1 : 0,
      max: length - 1
    });
    if (indexToRandomize === 0) {
      return randomAlphabeticChar() + previousUsername.substring(1, length);
    }

    return (
      previousUsername.substring(0, indexToRandomize) +
      randomAlphanumericChar(previousUsername.charAt(indexToRandomize)) +
      previousUsername.substring(indexToRandomize + 1, length)
    );
  }

  #randomizeIpAddress(previousIpAddress?: string): string {
    if (previousIpAddress === undefined) {
      return Array.from({ length: 4 }, () => randomIPv4AddressPart()).join('.');
    } else if (/[a-z]/i.exec(previousIpAddress) !== null) {
      return previousIpAddress.replace(/[a-z]+/gi, part =>
        String(randomIPv4AddressPart(part.length))
      );
    }

    const parts = previousIpAddress.split('.');
    const partToRandomize = chance.integer({ min: 0, max: parts.length - 1 });
    const part = parts[partToRandomize];
    if (part === undefined) {
      return previousIpAddress;
    }

    const partIndexToRandomize = chance.integer({
      min: 0,
      max: part.length - 1
    });

    const swap =
      chance.bool({ likelihood: 25 }) &&
      (partIndexToRandomize !== 0 || (part.length >= 2 && part[1] !== '0'));
    if (swap) {
      const char = part[partIndexToRandomize];
      const possibilities = parts.reduce(
        (acc, currentPart, i) => {
          if (i === partToRandomize || currentPart.length === 3) {
            return acc;
          }

          return [
            ...acc,
            ...Array.from({ length: currentPart.length + 1 }).map(
              (_, j) => [i, j] as const
            )
          ];
        },
        [] as readonly (readonly [number, number])[]
      );

      for (const [targetPartIndex, targetCharIndex] of shuffle(possibilities)) {
        const targetPart = parts[targetPartIndex];
        if (!targetPart) {
          continue;
        }

        const newTargetPart =
          targetPart.substring(0, targetCharIndex) +
          char +
          targetPart.substring(targetCharIndex, targetPart.length);
        if (
          !newTargetPart.startsWith('0') &&
          parseInt(newTargetPart, 10) <= 255
        ) {
          parts[targetPartIndex] = newTargetPart;
          parts[partToRandomize] =
            part.substring(0, partIndexToRandomize) +
            part.substring(partIndexToRandomize + 1, part.length);
          return parts.join('.');
        }
      }
    }

    for (const [partIndex, newDigit] of generateRandomIndexAndDigit(
      part.length
    )) {
      const newPart =
        part.substring(0, partIndex) +
        newDigit +
        part.substring(partIndex + 1, part.length);
      if (!newPart.startsWith('0') && parseInt(newPart, 10) <= 255) {
        parts[partToRandomize] = newPart;
        return parts.join('.');
      }
    }

    return parts.join('.');
  }

  #randomizeDomain(previousDomain?: string): string {
    if (previousDomain === undefined) {
      return `archidep${randomDigit()}.ch`;
    }

    const [domain, tld, ...rest] = previousDomain.split('.');
    if (domain === undefined || tld === undefined || rest.length !== 0) {
      return previousDomain;
    }

    if (chance.bool()) {
      return `${domain}.${tld}`;
    } else if (!domain.startsWith('archidep')) {
      return `archidep${randomDigit()}.${tld}`;
    }

    return `archidep${randomDigit(domain[8])}.${tld}`;
  }
}

const randomizeElements = document.getElementsByClassName(
  'archidep-randomize'
) as HTMLCollectionOf<HTMLElement>;
if (randomizeElements.length !== 0) {
  setUpRandomizers(randomizeElements);
}

function setUpRandomizers(elements: HTMLCollectionOf<HTMLElement>) {
  const currentElements = signal<readonly HTMLElement[]>([]);

  const options = {
    root: null,
    rootMargin: '0px',
    scrollMargin: '0px',
    threshold: 0.5
  };

  const observer = new IntersectionObserver(entries => {
    const currentEls = currentElements.value;
    const hiddenEntries = entries.filter(entry => !entry.isIntersecting);
    const stillVisible = currentEls.filter(
      el => !hiddenEntries.some(he => he.target === el)
    );
    currentElements.value = [
      ...stillVisible,
      ...entries
        .filter(
          entry =>
            entry.isIntersecting &&
            !stillVisible.includes(entry.target as HTMLElement)
        )
        .map(entry => entry.target as HTMLElement)
    ];
  }, options);

  for (const el of elements) {
    const id = `archidep-randomize-${chance.guid({ version: 4 })}`;
    el.id = id;
    const randomizer = Randomizer.for(el);
    if (randomizer) {
      observer.observe(randomizer.codeElement);
    }
  }

  effect(() => {
    const els = currentElements.value;
    if (els.length === 0) {
      return;
    }

    const interval = setInterval(() => {
      for (const el of els) {
        const randomizer = el[randomizerKey];
        if (randomizer instanceof Randomizer) {
          randomizer.randomize();
        }
      }
    }, 350);

    return () => clearInterval(interval);
  });
}

function findChildNodesMatching(
  node: Node,
  regexp: RegExp
): readonly [ChildNode, string, Readonly<Record<string, string>>][] {
  const matchingNodes: [ChildNode, string, Readonly<Record<string, string>>][] =
    [];
  for (const childNode of node.childNodes) {
    if (childNode.nodeType === Node.ELEMENT_NODE) {
      matchingNodes.push(
        ...findChildNodesMatching(childNode as HTMLElement, regexp)
      );
      continue;
    } else if (childNode.nodeType !== Node.TEXT_NODE) {
      continue;
    }

    const textContent = childNode.textContent;
    if (!textContent) {
      continue;
    }

    const match = regexp.exec(textContent);
    if (!match) {
      continue;
    }

    console.debug('@@@ child text node', childNode);
    matchingNodes.push([childNode, textContent, match?.groups ?? {}] as const);
  }

  return matchingNodes;
}

function randomAlphabeticChar(): string {
  return chance.character({ alpha: true, casing: 'lower' });
}

function randomAlphanumericChar(not?: string): string {
  const random = chance.character({
    alpha: true,
    numeric: true,
    casing: 'lower'
  });
  if (random === not) {
    return randomAlphanumericChar(not);
  }

  return random;
}

function randomDigit(not?: string): string {
  const random = chance.character({ numeric: true });
  if (random === not) {
    return randomDigit(not);
  }

  return random;
}

function* generateRandomIndexAndDigit(
  maxLength: number
): IterableIterator<[number, string]> {
  const indices = shuffle(Array.from({ length: maxLength }).map((_, i) => i));
  for (const index of indices) {
    for (const randomDigit of shuffle([
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9'
    ])) {
      yield [index, randomDigit];
    }
  }
}

function randomIPv4AddressPart(length?: number): number {
  if (length === 1) {
    return chance.integer({ min: 0, max: 9 });
  } else if (length === 2) {
    return chance.integer({ min: 10, max: 99 });
  } else if (length === 3) {
    return chance.integer({ min: 100, max: 255 });
  }

  return chance.integer({ min: 0, max: 255 });
}
