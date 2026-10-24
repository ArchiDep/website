// Keeps the aside beside a page within the window before it sticks, while it is
// still below the header: how far below is what `--aside-top` tells its
// stylesheet. See `ArchiDep.CourseSite.Layout.Chrome.Article`.
const $aside = document.getElementById('on-this-page-aside');

if ($aside) {
  let frame: number | undefined;
  let top: number | undefined;

  const fit = (): void => {
    frame = undefined;
    const next = Math.max(0, Math.round($aside.getBoundingClientRect().top));
    if (next !== top) {
      top = next;
      $aside.style.setProperty('--aside-top', `${next}px`);
    }
  };

  const scheduleFit = (): void => {
    frame ??= requestAnimationFrame(fit);
  };

  fit();
  window.addEventListener('scroll', scheduleFit, { passive: true });
  window.addEventListener('resize', scheduleFit);
}
