import {
  Story,
  type ChapterRenderConfig,
  type Operation,
  type RepoTarget,
  type Simulation
} from '@alphahydrae/simgit';

import {
  CALCULATOR,
  CALCULATOR_FILES,
  buildCalculatorStory,
  commitOf,
  johnDoe
} from './branching-stories';

// The `collaborating` story: the demo of the "Collaborating with Git" deck. It
// goes on from where the branching story ends, on `main` with the merge commit.
// The calculator is pushed to an empty repository of its author on GitHub, then
// to the team's repository, where a colleague has already pushed a commit. That
// push is rejected; the colleague's commit is fetched and merged, and the merge
// is pushed.
//
// The display digests are the ones the slides quote in their command output
// (`9dcba66..a92ed4f  main -> main`), so the diagram and the shell transcript
// beside it agree.

const ORIGIN: RepoTarget = { computer: 'github-jdoe', repo: '/git-calculator' };
const TEAM: RepoTarget = {
  computer: 'github-team',
  repo: '/git-calculator-team'
};
const ORIGIN_URL = `simgit://${ORIGIN.computer}${ORIGIN.repo}`;
const TEAM_URL = `simgit://${TEAM.computer}${TEAM.repo}`;

// A diagram shows the calculator beside one of the two GitHub repositories,
// never both: three computers stacked are too tall for a slide.
// `hiddenComputers` is explicit rather than sticky, so every chapter declares
// its view, and a play window starts on a chapter with the same view as the
// ones it plays.
const DEMO_VIEW: ChapterRenderConfig = {
  hiddenComputers: [ORIGIN.computer, TEAM.computer]
};
const ORIGIN_VIEW: ChapterRenderConfig = { hiddenComputers: [TEAM.computer] };
const TEAM_VIEW: ChapterRenderConfig = { hiddenComputers: [ORIGIN.computer] };

// simgit only draws the dashed network boundary between two computers created
// one after the other. The main story creates the calculator's computer, then
// its author's repository, then the team's; the diagrams of the team use a
// variant that creates the team's first.
const MAIN_ORDER: readonly string[] = [ORIGIN.computer, TEAM.computer];
const TEAM_ORDER: readonly string[] = [TEAM.computer, ORIGIN.computer];

function alice(): Record<string, string> {
  return {
    GIT_AUTHOR_NAME: 'Alice',
    GIT_AUTHOR_EMAIL: 'alice@archidep.ch',
    GIT_COMMITTER_NAME: 'Alice',
    GIT_COMMITTER_EMAIL: 'alice@archidep.ch',
    USER: 'alice',
    HOST: 'alice'
  };
}

function createComputers(
  order: readonly string[]
): (simulation: Simulation) => Promise<void> {
  return async simulation => {
    simulation.createComputer(CALCULATOR.computer, { env: johnDoe() });
    for (const name of order) {
      simulation.createComputer(name, {
        env: name === TEAM.computer ? alice() : johnDoe()
      });
    }

    for (const { computer, repo } of [CALCULATOR, ORIGIN, TEAM]) {
      await simulation.computer(computer, async c => {
        await c.mkdir(repo);
        await c.init(repo);
      });
    }
  };
}

/**
 * The team's repository starts from the calculator's first three commits, then
 * gets the colleague's commit.
 *
 * A push only moves a repository's refs, not the files of its working
 * directory, so the colleague's commit writes every file of the project, not
 * only the ones it changes.
 *
 * In the real repository, the colleague implements the subtraction in
 * `subtraction.js`, the same line the demo changes, so that the merge
 * conflicts. simgit merges per file and refuses a file changed differently on
 * both sides, so the colleague's subtraction goes into a file of its own here.
 * Only the commit graph is drawn, and it is the same either way; the slides
 * show the conflict markers themselves.
 */
function colleagueCommit(story: Story): Story {
  const files = CALCULATOR_FILES;
  return story
    .chapter(
      'team-history',
      async simulation => {
        await simulation.computer(CALCULATOR.computer, async computer => {
          await computer.repo(CALCULATOR.repo, async repo => {
            await repo.push(TEAM_URL, 'main');
          });
        });
      },
      DEMO_VIEW
    )
    .chapter(
      'team-colleague',
      {
        target: TEAM,
        operations: commitOf(
          TEAM,
          'Finish the calculator',
          {
            'index.html': '<h1>JavaScript Calculator</h1>\n',
            'LICENSE.txt': files.license,
            'README.md': files.readme,
            'addition.js': files.addition,
            'subtraction.js': files.subtraction,
            'subtraction-colleague.js':
              'function subtract(a, b) {\n  return -b + a;\n}\n'
          },
          '9dcba66'
        )
      },
      TEAM_VIEW
    );
}

/**
 * Made-up commits in one of the GitHub repositories, in chapters no embed plays.
 *
 * simgit sizes each repository to the most columns it reaches from the start of
 * the story to an embed's `through-chapter`: two repositories of a diagram only
 * get the same column width if they reach the same count. The calculator's
 * history reaches more columns than a GitHub repository at several points, so
 * the diagrams showing both end with `count` made-up commits in the GitHub
 * repository, and are sized through them.
 */
function padding(
  target: RepoTarget,
  count: number
): {
  readonly target: RepoTarget;
  readonly operations: readonly Operation[];
} {
  return {
    target,
    operations: Array.from({ length: count }, (_, i) =>
      commitOf(
        target,
        'Padding',
        { [`padding-${i + 1}.txt`]: 'padding\n' },
        `fff00${i + 1}`
      )
    ).flat()
  };
}

/**
 * A copy of `story` up to and including its chapter `lastChapter`, followed by
 * a chapter of made-up commits (see `padding`) named `padding`.
 */
function paddedAfter(
  story: Story,
  lastChapter: string,
  target: RepoTarget,
  count: number,
  view: ChapterRenderConfig
): Story {
  const copy = new Story(`${story.title}, after ${lastChapter}`);
  for (const chapter of story.chapters) {
    const { body } = chapter;
    if (body.kind === 'callback') {
      copy.chapter(chapter.title, body.actions, chapter.renderConfig);
    } else {
      copy.chapter(
        chapter.title,
        { target: body.target, operations: body.operations },
        chapter.renderConfig
      );
    }

    if (chapter.title === lastChapter) {
      return copy.chapter('padding', padding(target, count), view);
    }
  }

  throw new Error(`The story has no chapter "${lastChapter}"`);
}

const TEAM_PADDING_BEFORE_FETCH = 2;
const TEAM_PADDING_AFTER_FETCH = 3;

/**
 * The team's story up to the rejected push, for the diagrams of the team's
 * repository before the fetch.
 */
export function buildCollaboratingTeamBeforeFetchStory(): Story {
  return paddedAfter(
    buildCollaboratingTeamStory(),
    'team-rejected',
    TEAM,
    TEAM_PADDING_BEFORE_FETCH,
    TEAM_VIEW
  );
}

/**
 * The team's story up to the fetch, for the diagrams of the state after it.
 */
export function buildCollaboratingTeamFetchedStory(): Story {
  return paddedAfter(
    buildCollaboratingTeamStory(),
    'team-fetch',
    TEAM,
    TEAM_PADDING_AFTER_FETCH,
    TEAM_VIEW
  );
}

/**
 * The calculator's author pushes to their own repository, then to the team's,
 * where a colleague has already pushed. Chapter names are the ones the
 * collaboration slides reference.
 */
export function buildCollaboratingStory(): Story {
  return collaboratingStory('Collaborating', MAIN_ORDER);
}

/**
 * The same story, with the team's repository created right after the
 * calculator's computer, so that the diagrams showing the two of them draw the
 * network boundary between them.
 */
export function buildCollaboratingTeamStory(): Story {
  return collaboratingStory('Collaborating: the team', TEAM_ORDER);
}

function collaboratingStory(title: string, order: readonly string[]): Story {
  return (
    buildCalculatorStory(title, {
      init: createComputers(order),
      view: DEMO_VIEW,
      afterHistory: colleagueCommit
    })
      .chapter(
        'origin-add',
        {
          target: CALCULATOR,
          operations: [{ kind: 'remoteAdd', name: 'origin', url: ORIGIN_URL }]
        },
        ORIGIN_VIEW
      )
      .chapter(
        'origin-push',
        {
          target: CALCULATOR,
          operations: [{ kind: 'push', remote: 'origin', branch: 'main' }]
        },
        ORIGIN_VIEW
      )
      .chapter(
        'team-add',
        {
          target: CALCULATOR,
          operations: [{ kind: 'remoteAdd', name: 'team', url: TEAM_URL }]
        },
        TEAM_VIEW
      )
      // simgit cannot draw a rejected push: nothing moves, which is the point.
      .chapter('team-rejected', () => {}, TEAM_VIEW)
      .chapter(
        'team-fetch',
        {
          target: CALCULATOR,
          operations: [{ kind: 'fetch', remote: 'team' }]
        },
        TEAM_VIEW
      )
      .chapter(
        'team-merge',
        {
          target: CALCULATOR,
          operations: [
            { kind: 'merge', ref: 'team/main', displayDigest: 'a92ed4f' }
          ]
        },
        TEAM_VIEW
      )
      .chapter(
        'team-push',
        {
          target: CALCULATOR,
          operations: [{ kind: 'push', remote: 'team', branch: 'main' }]
        },
        TEAM_VIEW
      )
      // `origin` knows nothing of what happened with `team`.
      .chapter('origin-behind', () => {}, ORIGIN_VIEW)
      .chapter('origin-padding', padding(ORIGIN, 2), ORIGIN_VIEW)
  );
}
