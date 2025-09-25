import { GitMemoirController } from '../git-memoir/git-memoir-controller';

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
    '.reveal .slides .present git-memoir'
  );
}

function destroyGitMemoirsInCurrentRevealDeck() {
  GitMemoirController.destroyGitMemoirs('.reveal .slides git-memoir');
}
