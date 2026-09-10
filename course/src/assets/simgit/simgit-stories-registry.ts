import {
  Story,
  storyRegistry,
  type Operation,
  type Simulation
} from '@alphahydrae/simgit';

import { buildGithubStory } from './github-story';

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

// The subtraction implementation as it stands once the `feature-sub` work is
// merged. The `better-sub` branch commits this same content, so the merge that
// the slides narrate as a content conflict runs as an ordinary 3-way merge:
// simgit merges per path and only conflicts when a path is changed
// *differently* on both sides. The commit graph — the only thing rendered — is
// the same either way, and the slides carry the conflict markers themselves.
const SUBTRACTION_COMMENTED = `/**
 * Takes two numbers a and b, and returns
 * the result of subtracting b from a.
 */
function subtract(a, b) {
  return -b + a;
}

calculate('subtraction', subtract);
`;

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
 *
 * git-memoir interleaved no-op `*-settings` chapters to change layout mid-story;
 * simgit has per-chapter render config instead, so they are gone and the
 * chapters here are only the ones that do something.
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
 * The full story: the history diverges, both branches merge back, and two more
 * branches are cut from the common ancestor to stage the merge-conflict
 * chapters.
 *
 * `better-sub` and `cleanup` both start from `4f94fa` — a display digest, which
 * `startPoint` resolves, so the slides' hash and the story agree.
 */
function buildBranchingStory(): Story {
  return (
    buildBranchingBaseStory('Branching')
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
      .chapter('work-on-feature-branch', {
        target: CALCULATOR,
        operations: [{ kind: 'checkout', ref: 'feature-sub' }]
      })
      .chapter('commit-on-feature-branch', {
        target: CALCULATOR,
        operations: commitOf(
          'Comment subtract function',
          'subtraction.js',
          SUBTRACTION_COMMENTED,
          'f92ab0'
        )
      })
      .chapter('merge-checkout', {
        target: CALCULATOR,
        operations: [{ kind: 'checkout', ref: 'main' }]
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
      })
      .chapter('checkout-past', {
        target: CALCULATOR,
        operations: [
          { kind: 'branch', name: 'better-sub', startPoint: '4f94fa' },
          { kind: 'checkout', ref: 'better-sub' }
        ]
      })
      .chapter('conflicting-change', {
        target: CALCULATOR,
        operations: commitOf(
          'Implement a better subtract',
          'subtraction.js',
          SUBTRACTION_COMMENTED,
          '98ff62'
        )
      })
      .chapter('merge-conflicting-change-checkout', {
        target: CALCULATOR,
        operations: [{ kind: 'checkout', ref: 'main' }]
      })
      .chapter('merge-conflicting-change', {
        target: CALCULATOR,
        operations: [
          { kind: 'merge', ref: 'better-sub', displayDigest: 'a1d4e7' }
        ]
      })
      .chapter('delete-better-sub', {
        target: CALCULATOR,
        operations: [{ kind: 'deleteBranch', name: 'better-sub' }]
      })
      .chapter('conflicting-file-change-checkout', {
        target: CALCULATOR,
        operations: [
          { kind: 'branch', name: 'cleanup', startPoint: '4f94fa' },
          { kind: 'checkout', ref: 'cleanup' }
        ]
      })
      // The slides delete `subtraction.js` here; simgit has no file-removal
      // operation, so the commit touches `index.html` instead. `main` has not
      // changed that path since `4f94fa`, which also keeps the merge below clean.
      .chapter('conflicting-file-change', {
        target: CALCULATOR,
        operations: commitOf(
          'Remove incomplete implementation',
          'index.html',
          '<h1>Calculator</h1>\n<div id="keypad"></div>\n<div id="result"></div>\n',
          '12ac65'
        )
      })
      .chapter('merge-conflicting-file-change-checkout', {
        target: CALCULATOR,
        operations: [{ kind: 'checkout', ref: 'main' }]
      })
      .chapter('merge-conflicting-file-change', {
        target: CALCULATOR,
        operations: [{ kind: 'merge', ref: 'cleanup', displayDigest: 'c3b9f0' }]
      })
      .chapter('delete-cleanup', {
        target: CALCULATOR,
        operations: [{ kind: 'deleteBranch', name: 'cleanup' }]
      })
  );
}

storyRegistry.register('branchingOneLine', buildBranchingOneLineStory);
storyRegistry.register('branching', buildBranchingStory);
storyRegistry.register('github', buildGithubStory);
