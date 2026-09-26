import {
  Story,
  storyRegistry,
  type Operation,
  type Simulation
} from '@alphahydrae/simgit';

import { buildGithubStory } from './github-story';

// The course's simgit stories. Each story is registered under the name the
// `<simgit-story name='…'>` embeds in the course material use; a slide then
// picks the chapter it wants to stop on with `end-chapter`, so one story serves
// many slides.
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
 * The chapters both branching stories share: the JavaScript calculator gaining
 * a few commits, then a `feature-sub` branch, then a second `fix-add` branch.
 * Chapter names are the ones the branching slides reference.
 *
 * A chapter is one animated step, so each one holds exactly one Git command's
 * worth of work and a slide spans as many chapters as its shell transcript has
 * commands. Writing, staging and committing a file is one step, not three.
 */
function buildBranchingBaseStory(title: string): Story {
  return new Story(title)
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
    .chapter('second-commit', {
      target: CALCULATOR,
      operations: commitOf(
        'Fix addition',
        'addition.js',
        'export const add = (a, b) => a + b;\n',
        '9ab3fd'
      )
    })
    .chapter('third-commit', {
      target: CALCULATOR,
      operations: commitOf(
        'Improve layout',
        'index.html',
        '<h1>Calculator</h1>\n<div id="keypad"></div>\n',
        '4f94fa'
      )
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
        "function subtract(a, b) {\n  return a - b;\n}\n\ncalculate('subtraction', subtract);\n",
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

/**
 * The single-line story: the base chapters only, for the slides that introduce
 * branches while the history is still one line.
 */
function buildBranchingOneLineStory(): Story {
  return buildBranchingBaseStory('Branching (one line)');
}

/**
 * The full story: the history diverges and is switched back and forth, then
 * `fix-add` is merged back as a fast-forward and `feature-sub` with a
 * three-way merge.
 */
function buildBranchingStory(): Story {
  return buildBranchingBaseStory('Branching')
    .chapter('divergent-history', {
      target: CALCULATOR,
      operations: commitOf(
        'Fix addition',
        'addition.js',
        'export const add = (a, b) => a + b;\n// Handles floating point rounding.\n',
        '2817bc'
      )
    })
    .chapter('switch-to-feature-sub', {
      target: CALCULATOR,
      operations: [{ kind: 'checkout', ref: 'feature-sub' }]
    })
    .chapter('switch-to-fix-add', {
      target: CALCULATOR,
      operations: [{ kind: 'checkout', ref: 'fix-add' }]
    })
    .chapter('fast-forward-merge-checkout', {
      target: CALCULATOR,
      operations: [{ kind: 'checkout', ref: 'main' }]
    })
    .chapter('fast-forward-merge', {
      target: CALCULATOR,
      operations: [{ kind: 'merge', ref: 'fix-add' }]
    })
    .chapter('delete-branch', {
      target: CALCULATOR,
      operations: [{ kind: 'deleteBranch', name: 'fix-add' }]
    })
    .chapter('merge', {
      target: CALCULATOR,
      operations: [
        { kind: 'merge', ref: 'feature-sub', displayDigest: '04fb82' }
      ]
    })
    .chapter('delete-feature-sub', {
      target: CALCULATOR,
      operations: [{ kind: 'deleteBranch', name: 'feature-sub' }]
    });
}

storyRegistry.register('branchingOneLine', buildBranchingOneLineStory);
storyRegistry.register('branching', buildBranchingStory);
storyRegistry.register('github', buildGithubStory);
