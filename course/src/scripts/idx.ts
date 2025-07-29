import lunr from 'lunr';
import { readFile, writeFile } from 'node:fs/promises';
import ProgressBar from 'progress';

import { courseIndexFile, courseSearchFile } from './utils/constants';

const documents = JSON.parse(await readFile(courseSearchFile, 'utf-8'));

console.log('Building search index...');
const progress = new ProgressBar('[:bar] :current/:total :percent :what', {
  width: Math.min(30, process.stdout.columns),
  total: documents.length
});

const idx = lunr(function () {
  this.ref('id');
  this.field('title');
  this.field('text');
  this.field('extraText', { boost: 10 });
  this.metadataWhitelist = ['position'];

  for (const [i, doc] of documents.entries()) {
    progress.render({ what: doc.title });
    this.add(doc);
    progress.tick(i === documents.length - 1 ? { what: '' } : {});
  }
});

await writeFile(courseIndexFile, JSON.stringify(idx), 'utf-8');
