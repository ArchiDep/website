# Contributing

Please read this document to understand how this project is structured and what
guidelines to follow when contributing.

- [Project Structure](#project-structure)
- [Coding Guidelines](#coding-guidelines)
- [Project Tooling](#project-tooling)
- [Project Commands](#project-commands)

---

## Project Structure

This project contains multiple components which form a single system deployed
under a single base URL. Each components has its own `CONTRIBUTING.md` (and
`AGENTS.md`) files with component-specific instructions and guidelines. Refer to
those files for more details.

- **Main Components**
  - [`app/`](./app): Dashboard application for teachers and students,
    implemented with Phoenix (Elixir) and Phoenix LiveView

    See [`app/CONTRIBUTING.md`][app-contributing] and
    [`app/AGENTS.md`][app-agents] for more details.

  - [`course/`](./course): Course material site, implemented with Jekyll (Ruby)

    See [`course/CONTRIBUTING.md`][course-contributing] and
    [`course/AGENTS.md`][course-agents] for more details.

  - [`theme/`](./theme): Tailwind CSS theme for both the dashboard application
    and the course material site

    See [`theme/CONTRIBUTING.md`][theme-contributing] and
    [`theme/AGENTS.md`][theme-agents] for more details.

- **Other Directories**
  - `diagrams/`: OmniGraffle diagrams used in course materials.
  - `digest/`: Small Phoenix application to compute asset digests for cache
    busting without having to build the whole application.
  - `docker/`: Support files for the production Docker image and the local
    Docker development images.
  - `scripts/`: Utility scripts for local development.
  - `tmp/`: Temporary files created during local development or by developers.
  - `.github/`: CI/CD workflows and GitHub configuration.

- **Other Files**
  - `README.md`: Overview of the project, setup instructions and other general
    information.
  - `AGENTS.md`: Instructions and guidelines for AI assistants and automated
    agents interacting with the project.
  - `CONTRIBUTING.md`: Contribution guidelines for both human and AI
    contributors.
  - See the [Project Tooling](#project-tooling) section below for information
    about other tools used in this project and their configuration files.

---

## Coding Guidelines

This section provides general coding guidelines that apply to the entire
project. Refer to the `CONTRIBUTING.md` (and `AGENTS.md`) files in
subdirectories (`app`, `course` and `theme`) for more specific guidelines.

- **Frameworks, Languages and Libraries**
  - Dashboard application for teachers & students: Phoenix (Elixir), Phoenix
    LiveView, HTML/CSS
  - Course material site: Jekyll (Ruby), JavaScript/TypeScript, HTML/CSS
  - Theme: DaisyUI & Tailwind CSS

- **General Style**
  - Follow the conventions and best practices of the main frameworks, languages
    and libraries used in each component of the project (see above).
  - Prioritize clarity and maintainability over cleverness.
  - Avoid code duplication where possible, but do not over-engineer.
  - Consider accessibility in all UI changes.
  - Write modular and reusable code with clear separation of concerns.
  - Keep functions concise; prefer single-responsibility functions.
  - Avoid deeply nested code; refactor complex logic into smaller functions.

- **Documentation**
  - Do not comment simple functions whose purpose is clear from their name and
    signature. Prefer self-documenting code with descriptive names, explicit
    type annotations and clear logic.
  - Do comment functions that are part of the public API when their purpose or
    options are not immediately clear from their name and signature.
  - Also add inline comments to explain details that have no place in the
    function documentation, such as the reasoning behind a specific approach or
    implementation detail.
  - Private functions are implementation details and do not need to have
    documentation comments. Prefer inline comments to explain complex logic in
    private functions.
  - Use clear, descriptive comments for complex logic, but try to keep them
    concise.
  - Update the top-level `README.md` when introducing changes to the setup
    process.

- **Security**
  - Prioritize security in all code changes.
  - Always validate and sanitize user input.
  - Never expose sensitive data in logs, errors, or responses.
  - Never put secrets, passwords or API keys in source code that will be
    committed. Use environment variables or ignored files for sensitive
    configuration.

- **Communication**
  - Use clear, professional, concise, and constructive language in comments,
    suggestions and references.
  - This project is intended for educational purposes. Ensure that all content is
    appropriate for a learning environment.
  - That said, this project also contains some humorous elements and cultural
    references (mainly movies, sci-fi and video games). Feel free to engage with
    these in a light-hearted manner, but always maintain a respectful and
    professional tone.

---

## Project Tooling

This project uses several tools to facilitate development and ensure code
quality. This section documents tools used for the whole project. See the
`CONTRIBUTING.md` files in subdirectories (`app`, `course` and `theme`) for
component-specific frameworks, languages and tools.

- [ack](https://beyondgrep.com) is used for searching the codebase. See the
  [`.ackrc`](./.ackrc) files at the root of the repository and in
  subdirectories.
- [direnv](https://direnv.net) is used to set up environment variables for local
  development. See the [`.envrc`](./.envrc) file at the root of the repository.
- [Docker](https://www.docker.com) is used to run the application in production
  and as one alternative to set up a local development environment. See the
  [Dockerfile](./Dockerfile), [`.dockerignore`](./.dockerignore),
  [`compose.dev.yml`](./compose.dev.yml) and
  [`compose.prod.yml`](./compose.prod.yml) files at the root of the repository,
  as well as the contents of the [`docker/`](./docker) directory.

  The `.env` file at the root of the repository contains environment variables
  used for local development with Docker Compose. It is ignored by Git and
  should be created manually by copying the [`.env.sample`](./.env.sample) file
  and filling in the required values as documented in
  [`README.md`](./README.md).

- [asdf](https://asdf-vm.com) is used to install and manage the versions of
  programming languages and tools used in this project. The required versions
  are specified in the [`.tool-versions`](./.tool-versions) file at the root of
  the repository.
- [Prettier](https://prettier.io) is used to format a significant part of the
  code in this project (Ruby, JavaScript/TypeScript and HTML files that are not
  part of the Phoenix application). See the [`.prettierrc`](./.prettierrc) file
  at the root of the repository and in the `course` directory. Note that
  Prettier is not used for Elixir code in the `app` directory, as there is no
  widely adopted code

---

## Project Commands

This section documents the npm scripts that can be run from the root of the
repository. See the `CONTRIBUTING.md` files in subdirectories (`app`, `course`
and `theme`) for component-specific commands.

- `npm run doctoc`: Update the table of contents in various Markdown files.
- `npm run format`: Check code formatting in various languages using Prettier.
  This top-level command formats a lot of files and takes a little while to run.
  Prefer using the component-specific commands documented in the
  `CONTRIBUTING.md` files in subdirectories (`app`, `course` and `theme`) when
  working on a specific component.
- `npm run format:write`: Apply the source code formatting checked by `npm run format`.
- `npm run pdf`: Generate the PDF version of the course materials.

---

## For AI Agents

Follow the instructions and guidelines in this document and read the adjacent
[`AGENTS.md`](./AGENTS.md) file for additional instructions targeted towards AI
agents.

[agents]: ./AGENTS.md
[app-agents]: ./app/AGENTS.md
[app-contributing]: ./app/CONTRIBUTING.md
[course-agents]: ./course/AGENTS.md
[course-contributing]: ./course/CONTRIBUTING.md
[theme-agents]: ./theme/AGENTS.md
[theme-contributing]: ./theme/CONTRIBUTING.md
