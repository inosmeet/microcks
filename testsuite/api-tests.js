import * as tests from './commons.js';
import { flavorConfig } from './flavorConfig.js';
import { sleep } from 'k6';

const FLAVOR = __ENV.FLAVOR || 'uber';

export default function () {
  const toRun = flavorConfig[FLAVOR];
  if (!toRun) {
    console.error(`Unknown flavor "${FLAVOR}"`);
    return;
  }
  for (const fn of toRun) {
    console.log(`${fn}`);
    tests[fn]();
  }
}
