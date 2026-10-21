import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  RATE_WINDOW,
  SETTLED,
  Simulation,
  TURN,
  type Setup
} from './simulation';

interface Rates {
  readonly total: number;
  readonly rows: readonly [number, number];
}

function ratesOf(simulation: Simulation, time: number): Rates {
  simulation.advance(time);
  return {
    total: simulation.rate(time),
    rows: [simulation.rate(time, 0), simulation.rate(time, 1)]
  };
}

function settled(setup: Setup): Rates {
  return ratesOf(new Simulation(setup), SETTLED);
}

describe('Simulation', () => {
  it('serves one row 2 coffees per minute at one machine', () => {
    assert.deepEqual(settled('one-row'), { total: 2, rows: [2, 0] });
  });

  it('serves two rows at one machine as many in total, half each', () => {
    assert.deepEqual(settled('two-rows'), { total: 2, rows: [1, 1] });
  });

  it('serves two rows at two machines twice as many', () => {
    assert.deepEqual(settled('two-machines'), { total: 4, rows: [2, 2] });
  });

  it('serves the rows in turn at one machine', () => {
    const simulation = new Simulation('two-rows');
    simulation.advance(6 * TURN);

    assert.deepEqual(simulation.served, [
      { row: 0, at: 5 * TURN },
      { row: 1, at: 6 * TURN }
    ]);
  });

  it('gives the second row the next turn when it arrives', () => {
    const simulation = new Simulation('one-row');
    simulation.advance(SETTLED);
    assert.equal(simulation.next(SETTLED), 'two-rows');

    simulation.advance(SETTLED + 2 * TURN);

    assert.deepEqual(simulation.served, [
      { row: 0, at: 4 * TURN },
      { row: 1, at: 5 * TURN }
    ]);
  });

  it('settles at each step once a window has gone by', () => {
    const simulation = new Simulation('one-row');
    const second = SETTLED;
    const third = second + RATE_WINDOW + TURN;
    simulation.advance(second);
    simulation.next(second);
    const afterSecond = ratesOf(simulation, third - TURN / 2);
    simulation.next(third);
    const afterThird = ratesOf(simulation, third + RATE_WINDOW + TURN);

    assert.deepEqual(
      [afterSecond, afterThird],
      [
        { total: 2, rows: [1, 1] },
        { total: 4, rows: [2, 2] }
      ]
    );
  });
});
