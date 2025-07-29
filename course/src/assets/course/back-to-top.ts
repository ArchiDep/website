const $backToTopButton = document.getElementById('back-to-top');

if ($backToTopButton) {
  $backToTopButton.classList.add('hidden');
  $backToTopButton.addEventListener('click', goBackToTop);
  window.addEventListener('scroll', scroll($backToTopButton));
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
