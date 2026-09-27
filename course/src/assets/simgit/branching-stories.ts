import {
  Story,
  type ChapterRenderConfig,
  type Operation,
  type RepoTarget,
  type Simulation
} from '@alphahydrae/simgit';

// The branching stories of the "Version Control with Git" deck. A slide picks
// the chapter it wants to stop on with `end-chapter`, so one story serves many
// slides.
//
// The display digests are the ones the slides quote in their command output
// (`[sub 7f2a5d0] Implement subtraction`), so the diagram and the shell
// transcript beside it agree.

export const CALCULATOR: RepoTarget = {
  computer: 'demo',
  repo: '/git-calculator'
};

// The files of the calculator, reduced to what the diagrams need: only the
// commit graph is drawn, so each file only has to change when the real one does.
export const CALCULATOR_FILES = {
  index: '<h1>Calculator</h1>\n',
  license: 'The MIT License (MIT)\n',
  readme: '# Git Calculator\n',
  addition:
    '/** Returns the addition of a and b. */\nfunction add(a, b) {\n  return a * b;\n}\n',
  fixedAddition:
    '/** Returns the addition of a and b. */\nfunction add(a, b) {\n  return a + b;\n}\n',
  subtraction: "function subtract(a, b) {\n  return '?';\n}\n",
  implementedSubtraction: 'function subtract(a, b) {\n  return a - b;\n}\n'
} as const;

export function commitOf(
  target: RepoTarget,
  message: string,
  files: Readonly<Record<string, string>>,
  displayDigest: string
): readonly Operation[] {
  return [
    ...Object.entries(files).map(
      ([file, data]): Operation => ({
        kind: 'writeFile',
        path: `${target.repo}/${file}`,
        data,
        target
      })
    ),
    { kind: 'add', pathspecs: Object.keys(files), target },
    { kind: 'commit', message, displayDigest, target }
  ];
}

export function johnDoe(): Record<string, string> {
  return {
    GIT_AUTHOR_NAME: 'John Doe',
    GIT_AUTHOR_EMAIL: 'john.doe@archidep.ch',
    GIT_COMMITTER_NAME: 'John Doe',
    GIT_COMMITTER_EMAIL: 'john.doe@archidep.ch',
    USER: 'jdoe',
    HOST: 'localhost'
  };
}

async function createCalculatorRepo(simulation: Simulation): Promise<void> {
  simulation.createComputer(CALCULATOR.computer, { env: johnDoe() });

  await simulation.computer(CALCULATOR.computer, async computer => {
    await computer.mkdir(CALCULATOR.repo);
    await computer.init(CALCULATOR.repo);
  });
}

/**
 * How a story built on the calculator's history sets itself up: the first
 * chapter, which creates the computers, the view every chapter of the history
 * is drawn in, and the chapters it inserts once the repository has its first
 * three commits.
 */
export type CalculatorStorySetup = {
  readonly init: (simulation: Simulation) => Promise<void>;
  readonly view?: ChapterRenderConfig;
  readonly afterHistory?: (story: Story) => Story;
};

const DEMO_ONLY: CalculatorStorySetup = { init: createCalculatorRepo };

/**
 * The chapters every calculator story shares: the three commits of the example
 * repository, then a `sub` branch, then a second `fix-add` branch. Chapter
 * names are the ones the branching slides reference.
 *
 * A chapter is one animated step, so each one holds exactly one Git command's
 * worth of work and a slide spans as many chapters as its shell transcript has
 * commands. Writing, staging and committing a file is one step, not three.
 */
function buildBranchingBaseStory(
  title: string,
  { init, view, afterHistory = story => story }: CalculatorStorySetup
): Story {
  const files = CALCULATOR_FILES;
  const history = new Story(title)
    .chapter('init', init, view)
    .chapter(
      'setup',
      {
        target: CALCULATOR,
        operations: commitOf(
          CALCULATOR,
          'Initial commit',
          {
            'index.html': files.index,
            'addition.js': files.addition,
            'subtraction.js': files.subtraction
          },
          '073570e'
        )
      },
      view
    )
    .chapter(
      'second-commit',
      {
        target: CALCULATOR,
        operations: commitOf(
          CALCULATOR,
          'Add license',
          { 'LICENSE.txt': files.license },
          '24bb77c'
        )
      },
      view
    )
    .chapter(
      'third-commit',
      {
        target: CALCULATOR,
        operations: commitOf(
          CALCULATOR,
          'Add readme',
          { 'README.md': files.readme },
          '907e519'
        )
      },
      view
    );

  return afterHistory(history)
    .chapter(
      'branch',
      { target: CALCULATOR, operations: [{ kind: 'branch', name: 'sub' }] },
      view
    )
    .chapter(
      'checkout',
      { target: CALCULATOR, operations: [{ kind: 'checkout', ref: 'sub' }] },
      view
    )
    .chapter(
      'commit-on-a-branch',
      {
        target: CALCULATOR,
        operations: commitOf(
          CALCULATOR,
          'Implement subtraction',
          { 'subtraction.js': files.implementedSubtraction },
          '7f2a5d0'
        )
      },
      view
    )
    .chapter(
      'back-to-main',
      { target: CALCULATOR, operations: [{ kind: 'checkout', ref: 'main' }] },
      view
    )
    .chapter(
      'another-branch',
      {
        target: CALCULATOR,
        operations: [{ kind: 'checkout', ref: 'fix-add', newBranch: true }]
      },
      view
    );
}

/**
 * The single-line story: the base chapters only, for the slides that introduce
 * branches while the history is still one line.
 */
export function buildBranchingOneLineStory(): Story {
  return buildBranchingBaseStory('Branching (one line)', DEMO_ONLY);
}

/**
 * The full story: the history diverges and is switched back and forth, then
 * `fix-add` is merged back as a fast-forward and `sub` with a three-way merge.
 */
export function buildBranchingStory(): Story {
  return buildCalculatorStory('Branching', DEMO_ONLY);
}

/**
 * The full branching story, set up by `setup`: the collaboration story goes on
 * from where it ends, with more computers.
 */
export function buildCalculatorStory(
  title: string,
  setup: CalculatorStorySetup
): Story {
  const { view } = setup;
  return buildBranchingBaseStory(title, setup)
    .chapter(
      'divergent-history',
      {
        target: CALCULATOR,
        operations: commitOf(
          CALCULATOR,
          'Fix addition',
          { 'addition.js': CALCULATOR_FILES.fixedAddition },
          'a4160d7'
        )
      },
      view
    )
    .chapter(
      'switch-to-sub',
      { target: CALCULATOR, operations: [{ kind: 'checkout', ref: 'sub' }] },
      view
    )
    .chapter(
      'switch-to-fix-add',
      {
        target: CALCULATOR,
        operations: [{ kind: 'checkout', ref: 'fix-add' }]
      },
      view
    )
    .chapter(
      'fast-forward-merge-checkout',
      { target: CALCULATOR, operations: [{ kind: 'checkout', ref: 'main' }] },
      view
    )
    .chapter(
      'fast-forward-merge',
      { target: CALCULATOR, operations: [{ kind: 'merge', ref: 'fix-add' }] },
      view
    )
    .chapter(
      'delete-branch',
      {
        target: CALCULATOR,
        operations: [{ kind: 'deleteBranch', name: 'fix-add' }]
      },
      view
    )
    .chapter(
      'merge',
      {
        target: CALCULATOR,
        operations: [{ kind: 'merge', ref: 'sub', displayDigest: 'e0711c3' }]
      },
      view
    )
    .chapter(
      'delete-sub',
      {
        target: CALCULATOR,
        operations: [{ kind: 'deleteBranch', name: 'sub' }]
      },
      view
    );
}
