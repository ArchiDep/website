import {
  Story,
  type ChapterRenderConfig,
  type Operation,
  type RepoTarget,
  type Simulation
} from '@alphahydrae/simgit';

// The `guessit` story: the scripted collaboration of the Guess It exercise.
// Alice forks the exercise repository on GitHub, and she, Bob and Chuck clone
// it. Alice pushes a first change that the others fetch and pull. Then Alice
// and Bob change the same line: Alice pushes first, Bob's push is refused, and
// he pulls, resolves the conflict and pushes. Chuck, who changed another line,
// pulls and pushes without a conflict, and everyone pulls.
//
// The display digests are the ones the exercise quotes in its command output
// (`6f658d5..f739362  main -> main`), so the diagram and the shell transcript
// beside it agree. The first two are the real digests of the exercise
// repository, which every fork shares.

const ALICE: RepoTarget = { computer: 'alice', repo: '/guessit-ex' };
const GITHUB: RepoTarget = { computer: 'github', repo: '/guessit-ex' };
const BOB: RepoTarget = { computer: 'bob', repo: '/guessit-ex' };
const CHUCK: RepoTarget = { computer: 'chuck', repo: '/guessit-ex' };
const FORK_URL = 'simgit://github/guessit-ex';

// simgit sizes each repository to the most commits it reaches over the chapters
// an embed lays out, from the start of the story to its `through-chapter` (by
// default its `end-chapter`), and centres a smaller graph. Two repositories of
// a diagram only line up if they reach the same count, so an embed whose
// repositories do not extends `through-chapter` to a chapter where they do.
// When no later chapter of the story does so without adding an empty column,
// a variant of the story ends with made-up chapters that do (see
// `guessitStoryEndingWith`).
//
// A diagram shows GitHub beside one person, or between Alice and Bob; never
// more, because four computers do not fit side by side. `hiddenComputers` is
// explicit rather than sticky, so every chapter declares its view, and a play
// window starts on a chapter with the same view as the ones it plays.
const ALICE_VIEW: ChapterRenderConfig = { hiddenComputers: ['bob', 'chuck'] };
const BOB_VIEW: ChapterRenderConfig = { hiddenComputers: ['alice', 'chuck'] };
const CHUCK_VIEW: ChapterRenderConfig = { hiddenComputers: ['alice', 'bob'] };
const PAIR_VIEW: ChapterRenderConfig = { hiddenComputers: ['chuck'] };

function commitOf(
  target: RepoTarget,
  message: string,
  file: string,
  contents: string,
  displayDigest: string
): readonly Operation[] {
  return [
    {
      kind: 'writeFile',
      path: `${target.repo}/${file}`,
      data: contents,
      target
    },
    { kind: 'add', pathspecs: [file], target },
    { kind: 'commit', message, displayDigest, target }
  ];
}

function identity(name: string, display: string): Record<string, string> {
  return {
    GIT_AUTHOR_NAME: display,
    GIT_AUTHOR_EMAIL: `${name}@example.com`,
    GIT_COMMITTER_NAME: display,
    GIT_COMMITTER_EMAIL: `${name}@example.com`,
    USER: name,
    HOST: name,
    PWD: '/'
  };
}

// The computers are drawn in the order they are created, and simgit only draws
// the dashed network boundary between two computers created one after the
// other. The main story creates them in an order that puts GitHub between Alice
// and Bob; the diagrams of Chuck use a variant that puts him right after GitHub
// instead. Alice's fork is GitHub's repository, holding the exercise's two
// commits; a clone is a remote added to an empty repository, then pulled.
type ComputerName = 'alice' | 'github' | 'bob' | 'chuck';

const IDENTITIES: Readonly<Record<ComputerName, Record<string, string>>> = {
  alice: identity('alice', 'Alice'),
  github: identity('archidep', 'ArchiDep'),
  bob: identity('bob', 'Bob'),
  chuck: identity('chuck', 'Chuck')
};

const MAIN_ORDER: readonly ComputerName[] = ['alice', 'github', 'bob', 'chuck'];
const CHUCK_ORDER: readonly ComputerName[] = [
  'alice',
  'github',
  'chuck',
  'bob'
];

async function createComputers(
  simulation: Simulation,
  order: readonly ComputerName[]
): Promise<void> {
  for (const name of order) {
    simulation.createComputer(name, { env: IDENTITIES[name] });
  }

  for (const name of order) {
    await simulation.computer(name, async computer => {
      await computer.mkdir('/guessit-ex');
      await computer.init('/guessit-ex');
    });
  }
}

function cloneOf(target: RepoTarget): readonly Operation[] {
  return [
    { kind: 'remoteAdd', name: 'origin', url: FORK_URL, target },
    { kind: 'pull', remote: 'origin', target }
  ];
}

/**
 * Alice, Bob and Chuck collaborating on Alice's fork of Guess It.
 *
 * Alice's and Bob's accent colours conflict in `server.js`, and Chuck's title
 * merges with them on its own. simgit merges per path and refuses a path
 * changed differently on both sides, so each of these commits changes a file
 * of its own instead. Only the commit graph is drawn, and it is the same
 * either way; the exercise shows the conflict markers itself.
 *
 * Chuck's commit is made after his first pull rather than alongside Alice's and
 * Bob's, so that the chapters showing him stay together. His history is the
 * same either way, since he does not pull in between.
 */
export function buildGuessitStory(): Story {
  return guessitStory('Guess It', MAIN_ORDER);
}

/**
 * The same story, with Chuck created right after GitHub, so that the diagrams
 * showing the two of them draw the network boundary between them.
 */
export function buildGuessitChuckStory(): Story {
  return guessitStory('Guess It: Chuck', CHUCK_ORDER);
}

function guessitStory(title: string, order: readonly ComputerName[]): Story {
  return (
    new Story(title)
      .chapter(
        'fork',
        async simulation => {
          await createComputers(simulation, order);
        },
        ALICE_VIEW
      )
      .chapter(
        'exercise',
        {
          target: GITHUB,
          operations: [
            ...commitOf(
              GITHUB,
              'Initial commit',
              'server.js',
              "const ACCENT_COLOR = '#6c3ce9';\n",
              '1ec5d9b'
            ),
            ...commitOf(
              GITHUB,
              'Show total games played in leaderboard',
              'server.js',
              "const ACCENT_COLOR = '#6c3ce9';\nlet loaded = true;\n",
              '83ff81f'
            )
          ]
        },
        ALICE_VIEW
      )
      // Everyone clones, each in a chapter of their own: an operation on a
      // hidden computer cannot be drawn. The exercise only shows Alice's.
      .chapter(
        'clone',
        { target: ALICE, operations: cloneOf(ALICE) },
        ALICE_VIEW
      )
      .chapter('bob-clone', { target: BOB, operations: cloneOf(BOB) }, BOB_VIEW)
      .chapter(
        'chuck-clone',
        { target: CHUCK, operations: cloneOf(CHUCK) },
        CHUCK_VIEW
      )
      .chapter('alice-ready', () => {}, ALICE_VIEW)
      .chapter(
        'alice-readme',
        {
          target: ALICE,
          operations: commitOf(
            ALICE,
            'Add the team to the README',
            'README.md',
            '## Team\n',
            '6f658d5'
          )
        },
        ALICE_VIEW
      )
      .chapter(
        'alice-push',
        {
          target: ALICE,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        ALICE_VIEW
      )
      // Bob has not fetched yet: his `origin/main` is where it was.
      .chapter('bob-look', () => {}, BOB_VIEW)
      .chapter(
        'bob-fetch',
        { target: BOB, operations: [{ kind: 'fetch', remote: 'origin' }] },
        BOB_VIEW
      )
      .chapter(
        'bob-merge',
        { target: BOB, operations: [{ kind: 'merge', ref: 'origin/main' }] },
        BOB_VIEW
      )
      .chapter('chuck-look', () => {}, CHUCK_VIEW)
      .chapter(
        'chuck-pull',
        { target: CHUCK, operations: [{ kind: 'pull', remote: 'origin' }] },
        CHUCK_VIEW
      )
      .chapter('pair-look', () => {}, PAIR_VIEW)
      // Alice and Bob commit at the same time, on their own computers: one step.
      .chapter(
        'pair-commits',
        {
          target: ALICE,
          operations: [
            ...commitOf(
              ALICE,
              'Make the accent red',
              'accent-alice.js',
              "const ACCENT_COLOR = '#e63946';\n",
              'f739362'
            ),
            ...commitOf(
              BOB,
              'Make the accent green',
              'accent-bob.js',
              "const ACCENT_COLOR = '#2a9d8f';\n",
              '58ad519'
            )
          ]
        },
        PAIR_VIEW
      )
      .chapter(
        'alice-push-red',
        {
          target: ALICE,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        PAIR_VIEW
      )
      .chapter('bob-rejected', () => {}, BOB_VIEW)
      .chapter(
        'bob-fetch-red',
        { target: BOB, operations: [{ kind: 'fetch', remote: 'origin' }] },
        BOB_VIEW
      )
      .chapter(
        'bob-pull',
        {
          target: BOB,
          operations: [
            { kind: 'pull', remote: 'origin', displayDigest: '028ac6a' }
          ]
        },
        BOB_VIEW
      )
      .chapter('pair-merged', () => {}, PAIR_VIEW)
      .chapter(
        'bob-push-merge',
        {
          target: BOB,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        PAIR_VIEW
      )
      .chapter(
        'chuck-title',
        {
          target: CHUCK,
          operations: commitOf(
            CHUCK,
            'Sign the navbar',
            'title-chuck.js',
            '🎯 Guess It, by Alice, Bob &amp; Chuck\n',
            '99ecd8e'
          )
        },
        CHUCK_VIEW
      )
      .chapter(
        'chuck-pull-merge',
        {
          target: CHUCK,
          operations: [
            { kind: 'pull', remote: 'origin', displayDigest: '04e6514' }
          ]
        },
        CHUCK_VIEW
      )
      .chapter(
        'chuck-push-merge',
        {
          target: CHUCK,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        CHUCK_VIEW
      )
      .chapter('pair-behind', () => {}, PAIR_VIEW)
      // Alice and Bob pull at the same time: one step.
      .chapter(
        'final-pulls',
        {
          target: ALICE,
          operations: [
            { kind: 'pull', remote: 'origin', target: ALICE },
            { kind: 'pull', remote: 'origin', target: BOB }
          ]
        },
        PAIR_VIEW
      )
  );
}

/**
 * The story up to `lastChapter`, followed by chapters of fiction that no embed
 * plays. They only give repositories more commits for `through-chapter` to
 * count, so that two repositories of a diagram line up without an empty column
 * on the right: a repository whose next real commits would add too many columns,
 * or come too late, gets made-up ones instead.
 */
function guessitStoryEndingWith(
  title: string,
  lastChapter: string,
  ending: (story: Story) => Story
): Story {
  const story = new Story(title);
  for (const chapter of buildGuessitStory().chapters) {
    const { body } = chapter;
    if (body.kind === 'callback') {
      story.chapter(chapter.title, body.actions, chapter.renderConfig);
    } else {
      story.chapter(
        chapter.title,
        { target: body.target, operations: body.operations },
        chapter.renderConfig
      );
    }

    if (chapter.title === lastChapter) {
      return ending(story);
    }
  }

  throw new Error(`The Guess It story has no chapter "${lastChapter}"`);
}

/**
 * Bob's fetch of Alice's red accent. Bob has five commits after it, and GitHub
 * four, until Bob's merge takes it to six: one made-up commit on GitHub gives
 * both five columns.
 */
export function buildGuessitBobFetchStory(): Story {
  return guessitStoryEndingWith(
    'Guess It: Bob fetches',
    'bob-fetch-red',
    story =>
      story.chapter(
        'github-layout',
        {
          target: GITHUB,
          operations: commitOf(
            GITHUB,
            'Layout',
            'layout.txt',
            'layout\n',
            'fff0001'
          )
        },
        BOB_VIEW
      )
  );
}

/**
 * Bob's push of his merge. GitHub and Bob have six commits after it, and Alice
 * four, until the final pull takes everyone to eight: two made-up commits in
 * Alice's repository give all three six columns.
 */
export function buildGuessitBobPushMergeStory(): Story {
  return guessitStoryEndingWith(
    'Guess It: Bob pushes his merge',
    'bob-push-merge',
    story =>
      story.chapter(
        'alice-layout',
        {
          target: ALICE,
          operations: [
            ...commitOf(ALICE, 'Layout', 'layout-1.txt', 'layout\n', 'fff0001'),
            ...commitOf(ALICE, 'Layout', 'layout-2.txt', 'layout\n', 'fff0002')
          ]
        },
        PAIR_VIEW
      )
  );
}

/**
 * The end of the story in a group of two: there is no Chuck, so after Bob pushes
 * his merge, only Alice has anything to pull. Bob pushed last and is already up
 * to date.
 */
export function buildGuessitPairStory(): Story {
  return guessitStoryEndingWith(
    'Guess It: a group of two',
    'bob-push-merge',
    story =>
      story
        .chapter('pair-behind', () => {}, PAIR_VIEW)
        .chapter(
          'final-pulls',
          { target: ALICE, operations: [{ kind: 'pull', remote: 'origin' }] },
          PAIR_VIEW
        )
  );
}
