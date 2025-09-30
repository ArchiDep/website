const $backToTopSideButton = document.getElementById('back-to-top-side');

if ($backToTopSideButton) {
  $backToTopSideButton.classList.add('hidden');
  $backToTopSideButton.addEventListener('click', goBackToTop);
  window.addEventListener('scroll', scroll($backToTopSideButton));
}

const $backToTopBottomButton = document.getElementById('back-to-top-bottom');
if ($backToTopBottomButton) {
  $backToTopBottomButton.addEventListener('click', goBackToTop);
}

function scroll(button: HTMLElement): () => void {
  return () => {
    if (
      document.body.scrollTop > 20 ||
      document.documentElement.scrollTop > 20
    ) {
      button.classList.remove('hidden');
    } else {
      button.classList.add('hidden');
    }
  };
}

function goBackToTop(event: Event): void {
  event.preventDefault();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}
