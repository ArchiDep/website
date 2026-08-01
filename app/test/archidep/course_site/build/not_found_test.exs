defmodule ArchiDep.CourseSite.Build.NotFoundTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.Build.NotFound

  describe "html/1" do
    test "writes a page loading nothing, linking back to the mount point of the build" do
      urls = build(:url_context, mode: :backup, base_path: "/website", version: "2026")

      assert NotFound.html(urls) == """
             <!doctype html>
             <html lang="en">
             <head>
             <meta charset="utf-8" />
             <meta name="viewport" content="width=device-width, initial-scale=1" />
             <meta name="robots" content="noindex" />
             <title>Page not found · ArchiDep</title>
             <style>
             :root { color-scheme: light dark }
             body { display: flex; align-items: center; justify-content: center;
               min-height: 100vh; margin: 0; background: #eceff4; color: #2e3440;
               font-family: system-ui, sans-serif; line-height: 1.5 }
             main { max-width: 40rem; padding: 2rem; text-align: center }
             h1 { margin: 0 0 1rem; font-size: 4rem; line-height: 1; letter-spacing: -1px }
             @media (prefers-color-scheme: dark) {
               body { background: #0f172a; color: #b8c4d9 }
             }
             </style>
             </head>
             <body>
             <main>
             <h1>404</h1>
             <p><strong>Page not found :(</strong></p>
             <p>The requested page could not be found.</p>
             <p><a href="/website/">Back to the course</a></p>
             </main>
             </body>
             </html>
             """
    end

    test "links back into the edition an archived build holds, which keeps its own home page" do
      urls = build(:url_context, mode: :archive, base_path: "/backup", version: "2024")

      assert NotFound.html(urls) == """
             <!doctype html>
             <html lang="en">
             <head>
             <meta charset="utf-8" />
             <meta name="viewport" content="width=device-width, initial-scale=1" />
             <meta name="robots" content="noindex" />
             <title>Page not found · ArchiDep</title>
             <style>
             :root { color-scheme: light dark }
             body { display: flex; align-items: center; justify-content: center;
               min-height: 100vh; margin: 0; background: #eceff4; color: #2e3440;
               font-family: system-ui, sans-serif; line-height: 1.5 }
             main { max-width: 40rem; padding: 2rem; text-align: center }
             h1 { margin: 0 0 1rem; font-size: 4rem; line-height: 1; letter-spacing: -1px }
             @media (prefers-color-scheme: dark) {
               body { background: #0f172a; color: #b8c4d9 }
             }
             </style>
             </head>
             <body>
             <main>
             <h1>404</h1>
             <p><strong>Page not found :(</strong></p>
             <p>The requested page could not be found.</p>
             <p><a href="/backup/2024/">Back to the course</a></p>
             </main>
             </body>
             </html>
             """
    end
  end
end
