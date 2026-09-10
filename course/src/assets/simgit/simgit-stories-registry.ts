import {
  Story,
  storyRegistry,
  type Operation,
  type Simulation
} from '@alphahydrae/simgit';

// The course's simgit stories, the successor to the git-memoir registry. Each
// story is registered under the name the `<simgit-story name='…'>` embeds in
// the course material use; a slide then picks the chapter it wants to stop on
// with `end-chapter`, so one story serves many slides.
//
// The display digests are the ones the slides quote in their command output
// (`[feature-sub 712ff2] Implement subtraction`), so the diagram and the shell
// transcript beside it agree.

const CALCULATOR = { computer: 'demo', repo: '/git-branching-ex' };

function commitOf(
  message: string,
  file: string,
  contents: string,
  displayDigest: string
): readonly Operation[] {
  return [
    { kind: 'writeFile', path: `${CALCULATOR.repo}/${file}`, data: contents },
    { kind: 'add', pathspecs: [file] },
    { kind: 'commit', message, displayDigest }
  ];
}

async function createCalculatorRepo(simulation: Simulation): Promise<void> {
  simulation.createComputer(CALCULATOR.computer, {
    env: {
      GIT_AUTHOR_NAME: 'John Doe',
      GIT_AUTHOR_EMAIL: 'john.doe@archidep.ch',
      GIT_COMMITTER_NAME: 'John Doe',
      GIT_COMMITTER_EMAIL: 'john.doe@archidep.ch',
      USER: 'jdoe',
      HOST: 'localhost'
    }
  });

  await simulation.computer(CALCULATOR.computer, async computer => {
    await computer.mkdir(CALCULATOR.repo);
    await computer.init(CALCULATOR.repo);
  });
}

/**
 * The single-line branching story: the JavaScript calculator gaining a few
 * commits, then a `feature-sub` branch, then a second `fix-add` branch. Chapter
 * names are the ones the branching slides reference.
 *
 * git-memoir interleaved no-op `*-settings` chapters to change layout mid-story;
 * simgit has per-chapter render config instead, so they are gone and the
 * chapters here are only the ones that do something.
 */
function buildBranchingOneLineStory(): Story {
  return new Story('Branching (one line)')
    .chapter('init', createCalculatorRepo)
    .chapter('setup', {
      target: CALCULATOR,
      operations: commitOf(
        'First version',
        'index.html',
        '<h1>Calculator</h1>\n',
        '387f12'
      )
    })
    .chapter('commits', {
      target: CALCULATOR,
      operations: [
        ...commitOf(
          'Fix addition',
          'addition.js',
          'export const add = (a, b) => a + b;\n',
          '9ab3fd'
        ),
        ...commitOf(
          'Improve layout',
          'index.html',
          '<h1>Calculator</h1>\n<div id="keypad"></div>\n',
          '4f94fa'
        )
      ]
    })
    .chapter('branch', {
      target: CALCULATOR,
      operations: [{ kind: 'branch', name: 'feature-sub' }]
    })
    .chapter('checkout', {
      target: CALCULATOR,
      operations: [{ kind: 'checkout', ref: 'feature-sub' }]
    })
    .chapter('commit-on-a-branch', {
      target: CALCULATOR,
      operations: commitOf(
        'Implement subtraction',
        'subtraction.js',
        'export const subtract = (a, b) => a - b;\n',
        '712ff2'
      )
    })
    .chapter('back-to-main', {
      target: CALCULATOR,
      operations: [{ kind: 'checkout', ref: 'main' }]
    })
    .chapter('another-branch', {
      target: CALCULATOR,
      operations: [{ kind: 'checkout', ref: 'fix-add', newBranch: true }]
    });
}

storyRegistry.register('branchingOneLine', buildBranchingOneLineStory);
