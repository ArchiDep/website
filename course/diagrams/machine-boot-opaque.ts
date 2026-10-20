// The machine at boot once its processor is drawn opaque: a stack of cores,
// the buses, and the room on the right for the firmware, the memory, the
// storage and the devices. Its steps are to follow the boot.
import { diagram } from '../src/diagrams/build';

export default diagram({
  captions: {
    rest:
      'The processor drawn as a stack of cores, connected by the buses to the ' +
      'firmware, the memory, the disk controller and the device controllers. ' +
      'The storage and the devices are behind their controllers, and a device ' +
      'can interrupt the processor.',
    start: 'The processor, drawn as a box: what is inside it is no longer shown.'
  },
  steps: []
});
