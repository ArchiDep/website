import { isLeft } from 'fp-ts/lib/Either.js';
import * as t from 'io-ts';
import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';

import { getValidationErrorDetails } from '../../shared/codecs/utils';

/**
 * What a build of the course material site says of itself, for the step that
 * prints its pages: which pages there are, where each one is *in this build*,
 * and what the PDF of each is called. The build decides the names — the export
 * only writes the files under them.
 */

const manifestName = 'archidep.json';

const courseType = t.union([
  t.literal('cheatsheet'),
  t.literal('exercise'),
  t.literal('slides'),
  t.literal('subject')
]);

const courseHomeType = t.readonly(
  t.exact(
    t.type({
      url: t.string,
      pdf: t.string
    })
  )
);

const courseDocType = t.readonly(
  t.exact(
    t.type({
      title: t.string,
      num: t.number,
      course_type: courseType,
      url: t.string,
      pdf: t.string,
      slides_pdf: t.union([t.string, t.null])
    })
  )
);

const courseSectionType = t.readonly(
  t.exact(
    t.type({
      title: t.string,
      docs: t.readonlyArray(courseDocType)
    })
  )
);

const courseCheatsheetType = t.readonly(
  t.exact(
    t.type({
      title: t.string,
      sidebar_title: t.string,
      slug: t.string,
      url: t.string,
      pdf: t.string
    })
  )
);

const courseDataType = t.readonly(
  t.exact(
    t.type({
      home: courseHomeType,
      sections: t.readonlyArray(courseSectionType),
      cheatsheets: t.readonlyArray(courseCheatsheetType)
    })
  )
);

type CourseData = t.TypeOf<typeof courseDataType>;

export async function readCourseManifest(file: string): Promise<CourseData> {
  const decoded = courseDataType.decode(
    JSON.parse(await readFile(file, 'utf-8'))
  );
  if (isLeft(decoded)) {
    throw new Error(
      `Course data in ${file} is invalid: ${getValidationErrorDetails(decoded.left)}`
    );
  }

  return decoded.right;
}

/**
 * Find the manifest of the build written to the given directory.
 *
 * A build's own files sit under its edition prefix, which is the build's to
 * decide and not something the export can know; a build naming no edition has
 * none at all. Those are the two shapes looked for, and anything else has to be
 * named outright.
 */
export async function findCourseManifest(dir: string): Promise<string> {
  const atRoot = path.join(dir, manifestName);
  if (await isFile(atRoot)) {
    return atRoot;
  }

  const entries = await readdir(dir, { withFileTypes: true });
  const candidates: string[] = [];
  for (const entry of entries) {
    const candidate = path.join(dir, entry.name, manifestName);
    if (entry.isDirectory() && (await isFile(candidate))) {
      candidates.push(candidate);
    }
  }

  const [onlyCandidate] = candidates;
  if (onlyCandidate === undefined || candidates.length !== 1) {
    throw new Error(
      `Expected exactly one ${manifestName} in ${dir} or one level below it, found ${candidates.length}; pass --manifest`
    );
  }

  return onlyCandidate;
}

async function isFile(file: string): Promise<boolean> {
  const stats = await stat(file).catch(() => undefined);
  return stats?.isFile() === true;
}
