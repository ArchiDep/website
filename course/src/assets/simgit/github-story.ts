import {
  Story,
  type ChapterRenderConfig,
  type RepoTarget,
  type Operation,
  type Simulation
} from '@alphahydrae/simgit';

// The `github` story: the Hello GitHub exercise's collaboration narrative.
// Bob starts a project and publishes it to a shared GitHub repository, Alice
// clones it and pushes her own work, Bob fetches and merges, then the two
// diverge and Alice resolves it with a merge she pushes for Bob to pull.
//
// The display digests are the ones the exercise quotes in its command output
// (`92fb8c..3ff531  main -> origin/main`), so the diagram and the shell
// transcript beside it agree.

const BOB: RepoTarget = { computer: 'bob', repo: '/github-demo' };
const ALICE: RepoTarget = { computer: 'alice', repo: '/github-demo' };
const REMOTE_URL = 'simgit://github/github-demo';

// `hiddenComputers` is explicit rather than sticky — a chapter that does not
// declare it shows everyone — so each focus beat and every chapter it covers
// carries the set, mirroring the exercise's "this is now the state from Bob's
// perspective" asides.
const ONLY_BOB: ChapterRenderConfig = { hiddenComputers: ['github', 'alice'] };
const WITHOUT_ALICE: ChapterRenderConfig = { hiddenComputers: ['alice'] };
const WITHOUT_BOB: ChapterRenderConfig = { hiddenComputers: ['bob'] };
const EVERYONE: ChapterRenderConfig = { hiddenComputers: [] };

function commitOf(
  target: RepoTarget,
  message: string,
  file: string,
  contents: string,
  displayDigest: string
): readonly Operation[] {
  return [
    { kind: 'writeFile', path: `${target.repo}/${file}`, data: contents },
    { kind: 'add', pathspecs: [file] },
    { kind: 'commit', message, displayDigest }
  ];
}

function identity(name: string, display: string): Record<string, string> {
  return {
    GIT_AUTHOR_NAME: display,
    GIT_AUTHOR_EMAIL: `${name}@archidep.ch`,
    GIT_COMMITTER_NAME: display,
    GIT_COMMITTER_EMAIL: `${name}@archidep.ch`,
    USER: name,
    HOST: name,
    PWD: '/'
  };
}

// All three computers exist from the start; `hiddenComputers` reveals each one
// at the point the exercise introduces it, so Bob works alone first, then the
// shared repository appears, then Alice arrives.
async function createComputers(simulation: Simulation): Promise<void> {
  simulation.createComputer('bob', { env: identity('bob', 'Bob') });
  simulation.createComputer('github', { env: { PWD: '/' } });
  simulation.createComputer('alice', { env: identity('alice', 'Alice') });

  await simulation.computer('github', computer =>
    computer.init('/github-demo')
  );

  for (const name of ['bob', 'alice']) {
    await simulation.computer(name, async computer => {
      await computer.mkdir('/github-demo');
      await computer.init('/github-demo');
    });
  }
}

/**
 * Bob and Alice collaborating through a shared GitHub repository.
 *
 * Bob's fix and Alice's parallel change touch different files. The exercise
 * narrates them as a content conflict on `index.html`, but simgit merges per
 * path and would refuse a path changed differently on both sides; the commit
 * graph — all these embeds render — is the same either way, and the exercise
 * carries the conflict markers itself.
 */
export function buildGithubStory(): Story {
  return (
    new Story('GitHub')
      .chapter('init', createComputers, ONLY_BOB)
      .chapter(
        'staging',
        {
          target: BOB,
          operations: [
            ...commitOf(
              BOB,
              'First version',
              'index.html',
              '<h1>Calculator</h1>\n',
              '387f12'
            ),
            ...commitOf(
              BOB,
              'Add addition',
              'addition.js',
              'const add = (a, b) => a + b;\n',
              '9ab3fd'
            ),
            ...commitOf(
              BOB,
              'Rename computation scripts',
              'calculations.js',
              'const calculate = () => {};\n',
              '4f94ba'
            )
          ]
        },
        ONLY_BOB
      )
      // The shared GitHub repository enters the picture, still empty.
      .chapter('remote', () => {}, WITHOUT_ALICE)
      .chapter(
        'bob-remote',
        {
          target: BOB,
          operations: [{ kind: 'remoteAdd', name: 'origin', url: REMOTE_URL }]
        },
        WITHOUT_ALICE
      )
      .chapter(
        'bob-push',
        {
          target: BOB,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        WITHOUT_ALICE
      )
      // Alice arrives and clones the shared repository, which is a pull into the
      // empty repository she already has.
      .chapter(
        'alice-remote',
        {
          target: ALICE,
          operations: [{ kind: 'remoteAdd', name: 'origin', url: REMOTE_URL }]
        },
        EVERYONE
      )
      .chapter(
        'alice-pull',
        { target: ALICE, operations: [{ kind: 'pull', remote: 'origin' }] },
        EVERYONE
      )
      .chapter('alice-commit-settings', () => {}, WITHOUT_BOB)
      .chapter(
        'alice-commit',
        {
          target: ALICE,
          operations: commitOf(
            ALICE,
            'Add subtraction',
            'subtraction.js',
            'const subtract = (a, b) => a - b;\n',
            '92fb8c'
          )
        },
        WITHOUT_BOB
      )
      .chapter('alice-push-settings', () => {}, EVERYONE)
      .chapter(
        'alice-push',
        {
          target: ALICE,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        EVERYONE
      )
      .chapter('bob-look', () => {}, WITHOUT_ALICE)
      .chapter('bob-fetch-settings', () => {}, EVERYONE)
      .chapter(
        'bob-fetch',
        { target: BOB, operations: [{ kind: 'fetch', remote: 'origin' }] },
        EVERYONE
      )
      .chapter(
        'bob-merge',
        { target: BOB, operations: [{ kind: 'merge', ref: 'origin/main' }] },
        EVERYONE
      )
      .chapter('box-fix-settings', () => {}, EVERYONE)
      .chapter(
        'bob-fix',
        {
          target: BOB,
          operations: commitOf(
            BOB,
            'Fix bad <script> tags',
            'index.html',
            '<h1>Calculator</h1>\n<script src="add.js"></script>\n',
            '3ff531'
          )
        },
        EVERYONE
      )
      .chapter(
        'bob-fix-push',
        {
          target: BOB,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        EVERYONE
      )
      .chapter('alice-fix-prepare', () => {}, EVERYONE)
      .chapter(
        'alice-fix',
        {
          target: ALICE,
          operations: commitOf(
            ALICE,
            'Improve layout',
            'style.css',
            'h2 {\n  margin: 0;\n}\n',
            '102c34'
          )
        },
        EVERYONE
      )
      .chapter('alice-fix-check', () => {}, WITHOUT_BOB)
      .chapter('alice-fetch-changes-settings', () => {}, EVERYONE)
      .chapter(
        'alice-fetch-changes',
        { target: ALICE, operations: [{ kind: 'fetch', remote: 'origin' }] },
        EVERYONE
      )
      .chapter('alice-fetch-changes-check', () => {}, WITHOUT_BOB)
      .chapter('alice-fetch-changes-check-both', () => {}, EVERYONE)
      .chapter('alice-pull-changes-settings', () => {}, EVERYONE)
      .chapter(
        'alice-pull-changes',
        { target: ALICE, operations: [{ kind: 'pull', remote: 'origin' }] },
        EVERYONE
      )
      .chapter(
        'alice-push-merge',
        {
          target: ALICE,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        EVERYONE
      )
      .chapter('bob-pull-merge-prepare', () => {}, EVERYONE)
      .chapter(
        'bob-pull-merge',
        { target: BOB, operations: [{ kind: 'pull', remote: 'origin' }] },
        EVERYONE
      )
  );
}
