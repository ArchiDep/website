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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html';
import FlashyHooks from 'flashy';
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix';
import { LiveSocket } from 'phoenix_live_view';
import topbar from '../vendor/topbar';
import ClipboardJS from 'clipboard';

new ClipboardJS('[data-clipboard-target], [data-clipboard-text]');

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
      },
      destroyed() {
        const timer = this.el.dataset.remainingSecondsTimer;
        if (timer) {
          clearTimeout(timer);
        }
      }
    },
    ...FlashyHooks
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
    const timer = setTimeout(() => updateRemainingSeconds(element), 1000);
    element.dataset.remainingSecondsTimer = timer;
  } else {
    delete element.dataset.remainingSecondsTimer;
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
    if (!action) {
      console.warn(
        `No data-action-${actionName} attribute found on element ${element} for "phx:execute-action" event`
      );
      return;
    }

    liveSocket.execJS(element, action);
  });
});

// Closes the tooltip of a copy button 2 seconds after it was opened to confirm a
// copy, then resets its text 500 milliseconds later (to give time for the close
// animation). Both are the JS commands in the button's `data-tooltip-close` and
// `data-tooltip-reset` attributes: LiveView re-applies the commands that opened
// the tooltip on every patch of the button, until other commands undo them.
window.addEventListener('hide-tooltip', event => {
  const target = event.target;

  const targetId = target?.id;
  if (targetId === undefined || !target.classList.contains('tooltip')) {
    return;
  }

  if (target.dataset.tooltipTimer) {
    clearTimeout(target.dataset.tooltipTimer);
  }

  // The button is looked up again by its identifier when each timeout fires,
  // since a live view update may have replaced or removed it in the meantime.
  const executeOnTooltip = attribute => {
    const element = document.getElementById(targetId);
    const commands = element?.getAttribute(attribute);
    if (commands) {
      liveSocket.execJS(element, commands);
    }

    return element;
  };

  target.dataset.tooltipTimer = setTimeout(() => {
    const element = executeOnTooltip('data-tooltip-close');
    if (element !== null) {
      element.dataset.tooltipTimer = setTimeout(
        () => executeOnTooltip('data-tooltip-reset'),
        500
      );
    }
  }, 2000);
});

const standalone =
  document.querySelector('head').dataset['archidepStandalone'] === 'true';

// connect if there are any LiveViews on the page
if (!standalone) {
  liveSocket.connect();
}

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

function ifStillExists(id, callback) {
  const el = document.getElementById(id);
  if (el !== null) {
    callback(el);
  }
}
