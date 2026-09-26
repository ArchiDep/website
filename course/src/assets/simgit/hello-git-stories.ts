import { Story, type Operation, type Simulation } from '@alphahydrae/simgit';

// The stories of the Hello Git exercises. Each one replays what a student does
// in an exercise, so that the diagram can be compared with their own
// `git graph`.

type Repo = { readonly computer: string; readonly repo: string };

function createRepo(target: Repo): (simulation: Simulation) => Promise<void> {
  return async simulation => {
    simulation.createComputer(target.computer, {
      env: {
        GIT_AUTHOR_NAME: 'John Doe',
        GIT_AUTHOR_EMAIL: 'john.doe@example.com',
        GIT_COMMITTER_NAME: 'John Doe',
        GIT_COMMITTER_EMAIL: 'john.doe@example.com',
        USER: 'jdoe',
        HOST: 'localhost'
      }
    });

    await simulation.computer(target.computer, async computer => {
      await computer.mkdir(target.repo);
      await computer.init(target.repo);
    });
  };
}

function commitOf(
  target: Repo,
  message: string,
  file: string,
  contents: string,
  displayDigest?: string
): readonly Operation[] {
  return [
    { kind: 'writeFile', path: `${target.repo}/${file}`, data: contents },
    { kind: 'add', pathspecs: [file] },
    displayDigest === undefined
      ? { kind: 'commit', message }
      : { kind: 'commit', message, displayDigest }
  ];
}

const HELLO_GIT = { computer: 'laptop', repo: '/hello-git' };

/**
 * "Branch and switch": the student's own `hello-git` repository, with the
 * commits of the earlier exercises, gains a `bye` branch with one commit, then
 * switches back to `main`. The digests are the student's own, so none is
 * aliased.
 */
export function buildHelloGitBranchStory(): Story {
  const commit = (message: string, file: string, contents: string) =>
    commitOf(HELLO_GIT, message, file, contents);

  return new Story('Hello Git: branch and switch')
    .chapter('init', createRepo(HELLO_GIT))
    .chapter('history', {
      target: HELLO_GIT,
      operations: [
        ...commit('Add hello.txt', 'hello.txt', 'Hello World\n'),
        ...commit('Add hi.txt', 'hi.txt', 'Hi Bob\n'),
        ...commit(
          'Tell the world it is beautiful',
          'hello.txt',
          'Hello World\nYou are beautiful\n'
        ),
        ...commit(
          'Add trees of green',
          'hello.txt',
          'Hello World\nYou are beautiful\nI see trees of green\n'
        ),
        ...commit('Ignore secrets and logs', '.gitignore', '.env\n*.log\n'),
        ...commit('Configure the API', 'api-key.txt', 'API_KEY=sk-9f8e7d\n'),
        // The student's commit stops tracking `api-key.txt`; simgit has no
        // file-removal operation, and only the graph is rendered, so this one
        // changes `.gitignore` alone.
        ...commit(
          'Stop tracking the API key',
          '.gitignore',
          '.env\n*.log\napi-key.txt\n'
        )
      ]
    })
    .chapter('branch', {
      target: HELLO_GIT,
      operations: [{ kind: 'branch', name: 'bye' }]
    })
    .chapter('switch', {
      target: HELLO_GIT,
      operations: [{ kind: 'checkout', ref: 'bye' }]
    })
    .chapter('commit', {
      target: HELLO_GIT,
      operations: commit('Say goodbye', 'goodbye.txt', 'Goodbye World\n')
    })
    .chapter('back-to-main', {
      target: HELLO_GIT,
      operations: [{ kind: 'checkout', ref: 'main' }]
    });
}

const MERGES = { computer: 'laptop', repo: '/hello-git-merges' };

/**
 * The prepared `hello-git-merges` repository, as a student finds it after
 * cloning it, up to the `prepared` chapter. The digests of the prepared commits
 * are the repository's own, which are the same on every student's machine; the
 * merge commits' are not, so the stories built on it do not alias them.
 */
function buildHelloGitMergesBaseStory(title: string): Story {
  const commit = (
    message: string,
    file: string,
    contents: string,
    digest: string
  ) => commitOf(MERGES, message, file, contents, digest);

  // simgit's clock ticks once per chapter, and it lays commits out by time and
  // gives the main line to the oldest branch. Each commit and branch therefore
  // gets a chapter of its own, in the order the prepared repository made them;
  // `prepared` is the state a student starts from.
  return new Story(title)
    .chapter('init', createRepo(MERGES))
    .chapter('home-page', {
      target: MERGES,
      operations: commit(
        'Create the home page',
        'index.html',
        '<h1>Hello Git</h1>\n',
        '72208e4'
      )
    })
    .chapter('about-page', {
      target: MERGES,
      operations: commit(
        'Add an about page',
        'about.html',
        '<p>We are a smal team who loves Git.</p>\n',
        '3947df4'
      )
    })
    .chapter('contact-page-branch', {
      target: MERGES,
      operations: [{ kind: 'branch', name: 'contact-page' }]
    })
    .chapter('style', {
      target: MERGES,
      operations: commit(
        'Improve the style',
        'style.css',
        'body { max-width: 40em; }\n',
        'b85d48f'
      )
    })
    .chapter('fix-typo-branch', {
      target: MERGES,
      operations: [{ kind: 'checkout', ref: 'fix-typo', newBranch: true }]
    })
    .chapter('typo', {
      target: MERGES,
      operations: commit(
        'Fix a typo on the about page',
        'about.html',
        '<p>We are a small team who loves Git.</p>\n',
        '27d2a53'
      )
    })
    .chapter('contact-page-switch', {
      target: MERGES,
      operations: [{ kind: 'checkout', ref: 'contact-page' }]
    })
    .chapter('contact', {
      target: MERGES,
      operations: commit(
        'Add a contact page',
        'contact.html',
        '<h1>Contact us</h1>\n',
        '591343f'
      )
    })
    .chapter('contact-link', {
      target: MERGES,
      operations: commit(
        'Link to the contact page',
        'index.html',
        '<h1>Hello Git</h1>\n<a href="contact.html">Contact us</a>\n',
        '54bd3ee'
      )
    })
    .chapter('prepared', {
      target: MERGES,
      operations: [{ kind: 'checkout', ref: 'main' }]
    });
}

/**
 * "Two merges": `fix-typo` merged first (a fast-forward), then `contact-page`
 * (a three-way merge).
 */
export function buildHelloGitMergesStory(): Story {
  return buildHelloGitMergesBaseStory('Hello Git: two merges')
    .chapter('fast-forward', {
      target: MERGES,
      operations: [{ kind: 'merge', ref: 'fix-typo' }]
    })
    .chapter('three-way', {
      target: MERGES,
      operations: [{ kind: 'merge', ref: 'contact-page' }]
    });
}

/**
 * The advanced question of "Two merges": the same two merges in the reverse
 * order, where `fix-typo` can no longer fast-forward and needs a merge commit
 * of its own.
 */
export function buildHelloGitMergesReversedStory(): Story {
  return buildHelloGitMergesBaseStory('Hello Git: two merges, reversed')
    .chapter('contact-page-first', {
      target: MERGES,
      operations: [{ kind: 'merge', ref: 'contact-page' }]
    })
    .chapter('fix-typo-second', {
      target: MERGES,
      operations: [{ kind: 'merge', ref: 'fix-typo' }]
    });
}
