import {
  SimgitStoryElement,
  storyRegistry,
  verticalStackArrangement,
  type RenderLayout,
  type Story
} from '@alphahydrae/simgit';

import {
  buildBranchingOneLineStory,
  buildBranchingStory
} from './branching-stories';
import {
  buildCollaboratingStory,
  buildCollaboratingTeamBeforeFetchStory,
  buildCollaboratingTeamFetchedStory,
  buildCollaboratingTeamStory
} from './collaborating-story';
import {
  buildGuessitBobFetchStory,
  buildGuessitBobPushMergeStory,
  buildGuessitChuckStory,
  buildGuessitPairStory,
  buildGuessitStory
} from './guessit-story';
import {
  buildHelloGitBranchStory,
  buildHelloGitMergesReversedStory,
  buildHelloGitMergesStory
} from './hello-git-stories';

// Registers the course's simgit stories, each under the name the
// `<simgit-story name='…'>` embeds in the course material use.

storyRegistry.register('branchingOneLine', buildBranchingOneLineStory);
storyRegistry.register('branching', buildBranchingStory);
storyRegistry.register('helloGitBranch', buildHelloGitBranchStory);
storyRegistry.register('helloGitMerges', buildHelloGitMergesStory);
storyRegistry.register(
  'helloGitMergesReversed',
  buildHelloGitMergesReversedStory
);

// The stories drawing more than one computer, which need the layout below.
const multiComputerStories = new Set<string>();

function registerMultiComputer(name: string, builder: () => Story): void {
  storyRegistry.register(name, builder);
  multiComputerStories.add(name);
}

registerMultiComputer('collaborating', buildCollaboratingStory);
registerMultiComputer('collaboratingTeam', buildCollaboratingTeamStory);
registerMultiComputer(
  'collaboratingTeamBeforeFetch',
  buildCollaboratingTeamBeforeFetchStory
);
registerMultiComputer(
  'collaboratingTeamFetched',
  buildCollaboratingTeamFetchedStory
);
registerMultiComputer('guessit', buildGuessitStory);
registerMultiComputer('guessitBobFetch', buildGuessitBobFetchStory);
registerMultiComputer('guessitBobPushMerge', buildGuessitBobPushMergeStory);
registerMultiComputer('guessitChuck', buildGuessitChuckStory);
registerMultiComputer('guessitPair', buildGuessitPairStory);

// A multi-computer story needs both of these, and they are rich values the
// element takes by property rather than by attribute: the renderer otherwise
// draws every computer at the same origin, piling the story into one illegible
// heap, and without chrome the stacked repositories carry no machine names. The
// stack keeps each computer's intrinsic height rather than filling the canvas:
// these embeds size themselves to their content (`sizing='auto-height'`), so
// equal-height fill would give every computer the height of the tallest and
// leave a two-repository chapter three times taller than it needs to be.
const multiComputerLayout: RenderLayout = {
  containerArrangement: verticalStackArrangement(),
  showComputerChrome: true
};

/**
 * The `<simgit-story>` element, giving the multi-computer stories their layout
 * as each embed connects, just before it reads it. An embed may connect long
 * after the page has loaded: a deck's Markdown only becomes slides, and its
 * embeds elements, once reveal.js has initialized.
 */
class CourseSimgitStoryElement extends SimgitStoryElement {
  override connectedCallback(): void {
    const name = this.getAttribute('name');
    if (name !== null && multiComputerStories.has(name)) {
      this.renderLayout = multiComputerLayout;
    }

    super.connectedCallback();
  }
}

/**
 * Defines the `<simgit-story>` element, once the stories are registered, so
 * that the tags already in the page upgrade against a populated registry. Each
 * embed defers on its own IntersectionObserver and replays when it comes back
 * into view, so there is nothing to observe here.
 */
export function defineStoryElement(): void {
  if (customElements.get('simgit-story') === undefined) {
    customElements.define('simgit-story', CourseSimgitStoryElement);
  }
}
