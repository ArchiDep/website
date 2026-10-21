// The server of `machine-boot-opaque` once booted, running the SFTP deployment:
// Guess It and PostgreSQL in memory beside the SSH server and the session
// Guess It was started from, everything but the memory and those two drawn
// faded. No steps: it is the picture over which the room is asked how two
// isolated processes can communicate.
import { diagram } from '../src/diagrams/build/machine';

export default diagram({
  captions: {
    rest:
      'The booted server, running the SFTP deployment. Its memory holds the ' +
      'kernel, init, the SSH server, an SSH session and its shell, Guess It ' +
      'and PostgreSQL, each a process with its own memory.',
    start: 'The booted server, running the SFTP deployment.'
  },
  steps: []
});
