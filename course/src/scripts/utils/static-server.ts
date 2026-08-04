import { createReadStream } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import path from 'node:path';

export interface StaticServer {
  readonly baseUrl: string;
  readonly close: () => Promise<void>;
}

const html = 'text/html; charset=utf-8';

const contentTypes: Readonly<Record<string, string>> = {
  '.avif': 'image/avif',
  '.css': 'text/css; charset=utf-8',
  '.gif': 'image/gif',
  '.html': html,
  '.ico': 'image/x-icon',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.mp4': 'video/mp4',
  '.pdf': 'application/pdf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8',
  '.webm': 'video/webm',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.xml': 'application/xml'
};

/**
 * Serve a directory over loopback, the way a static host serves a built site: a
 * request for a directory is answered with that directory's `index.html`, and
 * anything else is the file at that path. That is the whole of what the pages
 * of a course build need — the files sitting next to a page and the global
 * assets are ordinary files under the same root — so nothing here knows what a
 * course is.
 *
 * Pass port 0 to have the operating system pick one; the returned base URL says
 * which.
 */
export async function serveDirectory(
  root: string,
  port: number
): Promise<StaticServer> {
  const notFound = await readFile(path.join(root, '404.html')).catch(() =>
    Buffer.from('Not found')
  );

  const server = createServer((req, res) => {
    void locate(root, req.url ?? '/')
      .then(file => {
        if (file === undefined) {
          res.writeHead(404, { 'content-type': html });
          res.end(notFound);
          return;
        }

        res.writeHead(200, {
          'content-type':
            contentTypes[path.extname(file).toLowerCase()] ??
            'application/octet-stream'
        });

        createReadStream(file)
          .on('error', () => res.destroy())
          .pipe(res);
      })
      .catch(() => {
        res.writeHead(500);
        res.end();
      });
  });

  // A client that goes away mid-request must not take the export down with it.
  server.on('clientError', (_err, socket) => socket.destroy());

  await new Promise<void>(resolve =>
    server.listen(port, '127.0.0.1', () => resolve())
  );

  const address = server.address() as AddressInfo;

  return {
    baseUrl: `http://127.0.0.1:${address.port}`,
    close: () =>
      new Promise<void>((resolve, reject) => {
        server.close(err => (err ? reject(err) : resolve()));
        // A browser keeps its connections alive, and the server will not finish
        // closing while it does, so the process would never exit.
        server.closeAllConnections();
      })
  };
}

// Where a URL path lands in the served directory, or nothing at all if it lands
// outside it or on nothing.
async function locate(root: string, url: string): Promise<string | undefined> {
  const { pathname } = new URL(url, 'http://localhost');
  const target = path.resolve(
    root,
    '.' + path.posix.normalize(decodeURIComponent(pathname))
  );

  if (target !== root && !target.startsWith(root + path.sep)) {
    return undefined;
  }

  const stats = await stat(target).catch(() => undefined);
  if (stats === undefined) {
    return undefined;
  } else if (!stats.isDirectory()) {
    return stats.isFile() ? target : undefined;
  }

  const index = path.join(target, 'index.html');
  const indexStats = await stat(index).catch(() => undefined);
  return indexStats?.isFile() === true ? index : undefined;
}
