// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

import { init } from '@plausible-analytics/tracker';
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html';
import FlashyHooks from 'flashy';
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix';
import { LiveSocket } from 'phoenix_live_view';
import topbar from '../vendor/topbar';

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content');
const liveSocket = new LiveSocket('/live', Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: {
    remainingSeconds: {
      mounted() {
        updateRemainingSeconds(this.el);
      }
    },
    ...FlashyHooks
  },
  dom: {
    onBeforeElUpdated: (fromEl, toEl) => {
      if (fromEl.tagName !== 'DIALOG') {
        return true;
      }

      // Prevent DOM updates from nuking the dialog state.
      toEl.open = fromEl.open;

      return false;
    }
  }
});

// Always clear the cached session on the login page.
if (window.location.pathname === '/login') {
  localStorage.removeItem('archidep:session');
}

function updateRemainingSeconds(element) {
  const endTime = new Date(element.dataset.endTime);
  const template = element.dataset.template || 'in {seconds}s';
  const doneTemplate = element.dataset.templateDone || 'soon';
  const remainingSeconds = Math.ceil(
    Math.max(0, endTime.getTime() - Date.now()) / 1000
  );
  element.textContent =
    remainingSeconds >= 1
      ? template.replace('{seconds}', remainingSeconds)
      : doneTemplate;

  if (remainingSeconds >= 1) {
    setTimeout(() => updateRemainingSeconds(element), 1000);
  }
}

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: '#29d' }, shadowColor: 'rgba(0, 0, 0, .3)' });
window.addEventListener('phx:page-loading-start', _info => topbar.show(300));
window.addEventListener('phx:page-loading-stop', _info => topbar.hide());

window.addEventListener('open-dialog', event => {
  const dialogId = event.detail?.dialog;
  if (!dialogId) {
    console.warn(`No dialog ID provided in "open-dialog" event detail`);
    return;
  }

  const dialog = document.getElementById(dialogId);
  if (!dialog) {
    console.warn(`Dialog with ID ${dialogId} not found`);
    return;
  }

  dialog.showModal();
});

// Cache session data relevant to the client in local storage.
window.addEventListener('phx:authenticated', event => {
  if (!event.detail) {
    console.warn('No event detail provided in "phx:authenticated" event');
    return;
  }

  const sessionExpiresAt = new Date(event.detail.sessionExpiresAt);
  if (sessionExpiresAt.getTime() > Date.now()) {
    localStorage.setItem('archidep:session', JSON.stringify(event.detail));
  } else {
    localStorage.removeItem('archidep:session');
  }
});

window.addEventListener('phx:close-dialog', event => {
  const dialogId = event.detail?.dialog;
  if (!dialogId) {
    console.warn(`No dialog ID provided in "phx:close-dialog" event detail`);
    return;
  }

  const dialog = document.getElementById(dialogId);
  if (!dialog) {
    console.warn(`Dialog with ID ${dialogId} not found`);
    return;
  }

  dialog.close();
});

window.addEventListener('phx:execute-action', event => {
  const to = event.detail?.to;
  if (!to) {
    console.warn(
      `No "to" selector provided in "phx:execute-action" event detail`
    );
    return;
  }

  const actionName = event.detail?.action;
  if (!actionName) {
    console.warn(`No "action" provided in "phx:execute-action" event detail`);
    return;
  }

  document.querySelectorAll(to).forEach(element => {
    const action =
      element.getAttribute(`data-action-${actionName}`) ?? undefined;
    if (!actionName) {
      console.warn(
        `No data-action-${actionName} attribute found on element ${element} for "phx:execute-action" event`
      );
      return;
    }

    liveSocket.execJS(element, action);
  });
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

init({
  domain: 'archidep.ch',
  endpoint: 'https://plausible.alphahydrae.ch/api/event',
  autoCapturePageviews: false,
  outboundLinks: true
});

trackEvent('pageview');

let lastPage;

window.addEventListener('phx:page-loading-stop', event => {
  if (
    event.detail?.kind === 'initial' ||
    window.location.pathname === lastPage
  ) {
    return;
  }

  lastPage = window.location.pathname;
  trackEvent('pageview');
});

function trackEvent(name, props = {}) {
  const plausible = window['plausible'];
  if (plausible === undefined) {
    return;
  }

  plausible(name, { props, callback: trackCallback });
}

function trackCallback(result) {
  if (result !== undefined && 'status' in result) {
    console.debug(`Plausible request done with status ${result.status}`);
  } else if (result?.error) {
    console.warn('Plausible request error', result.error);
  } else {
    console.warn('Plausible request ignored');
  }
}
