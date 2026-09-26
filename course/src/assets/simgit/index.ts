import { storyRegistry } from '@alphahydrae/simgit';

import {
  buildBranchingOneLineStory,
  buildBranchingStory
} from './branching-stories';
import { buildGithubStory } from './github-story';
import {
  buildHelloGitBranchStory,
  buildHelloGitMergesReversedStory,
  buildHelloGitMergesStory
} from './hello-git-stories';

// Registers the course's simgit stories, each under the name the
// `<simgit-story name='…'>` embeds in the course material use.

storyRegistry.register('branchingOneLine', buildBranchingOneLineStory);
storyRegistry.register('branching', buildBranchingStory);
storyRegistry.register('github', buildGithubStory);
storyRegistry.register('helloGitBranch', buildHelloGitBranchStory);
storyRegistry.register('helloGitMerges', buildHelloGitMergesStory);
storyRegistry.register(
  'helloGitMergesReversed',
  buildHelloGitMergesReversedStory
);
