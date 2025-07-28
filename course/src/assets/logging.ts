import log from 'loglevel';
import logPrefix from 'loglevel-plugin-prefix';

log.setDefaultLevel(
  window.location.hostname === 'localhost' ? log.levels.DEBUG : log.levels.INFO
);

logPrefix.reg(log);
logPrefix.apply(log, {
  template: '[%t] %l <%n>:'
});

export default log;
