// Setting up the server of "Deploy a web application with SFTP", 1 of 3. The
// SSH connection is already open and folded away, being only how commands are
// typed: what matters is what installing starts, and what it does not.
import {
  diagram,
  shortLived,
  show,
  step
} from '../src/diagrams/build/processes';

const SHELL = 'node-remote-shell';

export default diagram({
  captions: {
    rest:
      'PostgreSQL is installed and running on your server, listening on port ' +
      '5432. Node.js is installed, but nothing of it runs.',
    start:
      'You start the exercise by connecting to your server over SSH. ' +
      'This diagram shows that connection already open. ' +
      'The following steps show what happens when you type commands on the server.'
  },
  steps: [
    step(
      'You run <code>sudo apt install postgresql</code>. APT downloads ' +
        'PostgreSQL, installs it, and exits.',
      shortLived(
        'node-apt-postgresql',
        SHELL,
        'edge-remote-shell-apt-postgresql'
      )
    ),
    step(
      'Installing PostgreSQL also started it. It listens on port 5432, and on ' +
        'a Unix socket, a file through which programs on the same server can ' +
        'connect to it. Something started it automatically: more on that ' +
        'later in the course.',
      show('node-postgresql')
    ),
    step(
      'You install Node.js: you install <code>curl</code>, download and run ' +
        'NodeSource’s setup script with it, which adds their repository, then ' +
        'run <code>sudo apt-get install -y nodejs</code>. APT installs it, ' +
        'and exits. Nothing new stays running: ' +
        'installing a program only puts its files on the disk.',
      shortLived('node-apt-nodejs', SHELL, 'edge-remote-shell-apt-nodejs')
    ),
    step(
      'You run <code>node -v</code>. Installed, Node.js is only files on the ' +
        'disk: it runs only when you start it, and here, it stops as soon as ' +
        'it has printed its version.',
      shortLived('node-node-version', SHELL, 'edge-remote-shell-node-version')
    )
  ]
});
