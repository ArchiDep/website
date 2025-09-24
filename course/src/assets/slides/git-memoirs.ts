import { GitMemoirController } from '../git-memoir/git-memoir-controller';

const currentRevealDeckGitMemoirsSelector =
  '.reveal .slides .present git-memoir';

export function startGitMemoirsForRevealDeck(deck: Reveal.Api) {
  let memoirsCount = startGitMemoirsInCurrentRevealDeck();
  deck.on('slidechanged', () => {
    if (memoirsCount !== 0) {
      destroyGitMemoirsInCurrentRevealDeck();
    }

    memoirsCount = startGitMemoirsInCurrentRevealDeck();
  });
}

function startGitMemoirsInCurrentRevealDeck() {
  return GitMemoirController.startGitMemoirs(
    currentRevealDeckGitMemoirsSelector
  );
}

function destroyGitMemoirsInCurrentRevealDeck() {
  GitMemoirController.destroyGitMemoirs(currentRevealDeckGitMemoirsSelector);
}
