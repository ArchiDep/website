# Contributing

This document describes the **web layer** (`ArchiDepWeb`) of the ArchiDep
dashboard application — the Phoenix interface built on top of the [bounded
contexts][bounded-contexts]. It is part of the application documented in the
[`app/CONTRIBUTING.md`][app-contributing] file at the application root, which
covers the overall architecture, coding guidelines,
[authorization][authorization] and tooling that also apply here. Read that
document first.

> **Note:** This document covers the web framework, routing, real-time
> integration, the user-facing pages, the [admin console](#admin-console), the
> [server UI](#servers-ui) and the shared UI, notifications and i18n.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
- [The Web Kernel](#the-web-kernel)
- [Routing, Endpoint & Pipelines](#routing-endpoint--pipelines)
- [Real-Time Integration](#real-time-integration)
- [Live Read-Models](#live-read-models)
- [User-Facing Pages](#user-facing-pages)
- [Admin Console](#admin-console)
- [Servers UI](#servers-ui)
- [Components & Layouts](#components--layouts)
- [Notifications](#notifications)
- [Internationalization](#internationalization)
- [Helpers](#helpers)
- [Errors, Health & Telemetry](#errors-health--telemetry)
- [Authentication & Authorization](#authentication--authorization)
- [References](#references)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## Overview

`ArchiDepWeb` is the **Web Layer** of the [three-tier
architecture][app-contributing]: it turns HTTP requests and WebSocket
connections into calls on the [bounded contexts][bounded-contexts] and renders
the result with Phoenix LiveView. It also:

- **serves the compiled course material site** from `priv/static` (the Jekyll
  [`course`](../../../course/CONTRIBUTING.md) build outputs there), and
- **drives that site in real time** over a WebSocket channel (see [Real-Time
  Integration](#real-time-integration)).

The main areas are the [user-facing pages](#user-facing-pages) (dashboard, my
servers, profile), the [admin console](#admin-console), the [server
UI](#servers-ui), the shared [components & layouts](#components--layouts), and
the cross-cutting [auth](#authentication--authorization),
[notifications](#notifications) and [i18n](#internationalization) plumbing.

---

## The Web Kernel

[`archidep_web.ex`](../archidep_web.ex) defines the `use ArchiDepWeb, :kind`
macros that every web module starts from — `:router`, `:endpoint`,
`:controller`, `:live_view`, `:live_component`, `:component`, `:html`,
`:channel` and `:verified_routes`. Each injects the right imports/aliases (the
core components, the [auth helpers](#authentication--authorization), Gettext,
verified routes, etc.).

Two things worth knowing:

- The **`:live_view`** macro adds `on_mount(ArchiDepWeb.LiveAuth)`, so **every
  live view is authenticated** by default (see [Authentication &
  Authorization](#authentication--authorization)).
- Routes are referenced with **verified routes** (`~p"/..."`), so broken links
  are caught at compile time.

---

## Routing, Endpoint & Pipelines

[`endpoint.ex`](./endpoint.ex) mounts two sockets — the LiveView socket at
`/live` and the [`UserSocket`](#real-time-integration) at `/socket` — runs the
usual plug pipeline (Sentry capture, request id, telemetry, parsers, session),
and serves the static course site via `Plug.Static` (from `priv/static`, limited
to [`ArchiDepWeb.static_paths/0`](../archidep_web.ex)).

[`router.ex`](./router.ex) defines three pipelines — `:browser` (session, CSRF,
secure headers, SSL), `:api` (JSON, SSL) and `:dev` — and these route groups:

- **Public auth routes** (the `Auth` controller): `/login`, `/logout`,
  `/auth/...` (Switch edu-ID OIDC, login link, CSRF/socket tokens,
  impersonation) — see the [Accounts
  context](../archidep/accounts/CONTRIBUTING.md#web-wiring).
- **Authenticated pages** in a single `live_session :default` (with
  `on_mount: [Flashy.Hook, ArchiDepWeb.LiveHooks]` and `pipe_through
:fetch_authentication`): `/profile`, the [dashboard](#user-facing-pages)
  (`/app`, `/app/my-servers`), the user-facing [server page](#servers-ui)
  (`/servers/:id`), and the `/admin/...` [admin console](#admin-console).
- **API callbacks:** `/api/callbacks/servers/:id/up` (the [token-authenticated
  server callback](../archidep/servers/CONTRIBUTING.md#use-cases)) and
  `/api/health` (see [Errors, Health & Telemetry](#errors-health--telemetry)).
- **Dev only:** the [LiveDashboard](#errors-health--telemetry) at
  `/dev/dashboard` and the Swoosh mailbox preview at `/dev/mailbox`.

> **Authorization note:** there is **no router-level "require root" pipeline**.
> The `/admin` routes live in the same authenticated `live_session` as the
> student pages; root access is enforced because each admin page loads root-only
> [context operations](#admin-console). See [Authentication &
> Authorization](#authentication--authorization).

---

## Real-Time Integration

The course material site is a static site, but it behaves like part of the app
because the browser opens an authenticated WebSocket back to it. This is the
server side of the channel client documented in the [course material
docs](../../../course/CONTRIBUTING.md#client-side-architecture).

- **[`UserSocket`](./channels/user_socket.ex)** (`/socket`) authenticates the
  connection: the client first fetches a short-lived (`5 min`) `Phoenix.Token`
  from `/auth/socket`, and the socket verifies it (`"user socket"` salt) and
  resolves the session via
  [`Accounts.validate_session_id/2`](../archidep/accounts/CONTRIBUTING.md), then
  assigns `auth`.
- **[`UserChannel`](./channels/user_channel.ex)** (the `"me"` topic) subscribes
  to the [Course](../archidep/course/CONTRIBUTING.md) and
  [Servers](../archidep/servers/CONTRIBUTING.md) PubSub topics for the current
  student and their servers, and pushes two messages to the browser whenever
  anything changes:
  - **`session`** — a [`ClientSessionData`](./client_session_data.ex) struct
    (username, root/impersonating flags, session expiry, and the student's
    username/domain), and
  - **`cloudServerData`** — a
    [`ClientCloudServerData`](./client_cloud_server_data.ex) struct (the
    student's single active server's name/IP/URL, or `nil`, plus whether servers
    are enabled).

This is what keeps the course site's header, login state and **cloud server
widget** live without it calling any REST API. The same `ClientSessionData` is
also pushed by [`LiveAuth`](./live_auth.ex) when a live view mounts.

---

## Live Read-Models

Many pages keep a cached read-model current from the [bounded
contexts][bounded-contexts]' PubSub broadcasts (a renamed class, a server
changing state). A live view does **not** name topics or events itself; it
delegates both halves to the owning context:

- on connected mount it calls the context's `subscribe_*` function, which
  subscribes the calling process to every topic (own-context and cross-context)
  that keeps that read-model live;
- it attaches [`LiveRefresh`](./live_refresh.ex) with a context refresher that
  owns the message → refresh decision. Pick the variant by what the assign is:
  - `LiveRefresh.attach(socket, :key, &Context.refresh_<entity>/2)` when the
    refresher owns the **whole assign** — a single value, or a full list whose
    refresher handles create, update, delete _and_ ordering (its refresher takes
    the current value/list and returns the new one);
  - `attach_collection/3` only when a list's **membership is fixed** and just
    element updates matter — it hands a per-element refresher each element and
    replaces the one that claims the message in place. It cannot express a
    create (there is no element to hand the refresher), so a full-CRUD list uses
    `attach/3` with a whole-list refresher instead.
  - `attach_all/2` when **one message feeds more than one single-value assign**
    — it takes a list of `{key, refresher}` pairs, runs each against its own
    assign, and halts when at least one claims the message. A chain of
    `attach/3` hooks cannot express this: the first hook to claim a message
    halts the rest, so two assigns that both react to the same broadcast would
    starve one of them.

A refresher returns `{:ok, updated}` for a message it claims or `:ignore` for
anything else. The `:handle_info` hook swaps the assign and halts on a claimed
message, and lets everything else fall through to the live view's own
`handle_info/2` clauses. This keeps the "what feeds this read-model" knowledge in
the owning context instead of spread across every consumer. Exemplars:

- [`profile_live.ex`](./profile/profile_live.ex) — single value, backed by
  `Course.subscribe_student/1` + `Course.refresh_student/2`.
- [`server_live.ex`](./servers/server_live.ex) — single value, backed by
  `Servers.subscribe_server/1` + `Servers.refresh_server/2`; shows the hook
  coexisting with a page's own `handle_info/2` clauses (it halts `:server_updated`
  while the tracker's `:server_state` messages and the `:server_deleted` notice
  fall through to the page).
- [`classes_live.ex`](./admin/classes/classes_live.ex) — whole list, backed by
  `Course.subscribe_classes/0` + `Course.refresh_classes/2`; the refresher owns
  create, update, delete and ordering, so the page names nothing and needs no
  `handle_info/2` at all.
- [`my_servers_live.ex`](./dashboard/my_servers_live.ex) — whole list, backed by
  `Servers.subscribe_my_servers/1` + `Servers.refresh_my_servers/2`; the
  refresher reconciles server-field updates (and re-sorts), while creation and
  deletion fall through to the page because they also start/stop the server
  tracker — a process-local side effect that cannot live in a context refresher.
- [`class_live.ex`](./admin/classes/class_live.ex) — several independent
  read-models on one page, each its own `attach/3`: the class
  (`Course.refresh_class/2`), the student list
  (`Course.refresh_class_students/4`, a whole-list refresher whose closure
  captures `auth`/`class`) and the set of its server IDs
  (`Servers.refresh_server_ids/2`). The only surviving `handle_info/2` clause is
  `:class_deleted`, which navigates away.

**Choosing the topic.** The `subscribe_*` function picks the _coarsest_ topic
whose audience is "everyone who would care about any of these events", and
subscribes to it once on mount — never per entity as rows come and go. An
admin-wide list uses the global per-type topic (`classes`); a user's own servers
use the owner-scoped topic (`server-owners:<id>:servers`, which carries every
create/update/delete for that owner). Per-entity topics are only worth their
dynamic subscribe/unsubscribe bookkeeping when a page shows _one_ entity out of
very many; at this project's scale, PubSub fan-out is never the bottleneck, so
prefer the coarser topic and the simpler, static subscription.

A `subscribe_*` function may cover **cross-context** topics too, so the page
still names none: `Course.subscribe_class_students/1` subscribes to the Course
students topic _and_ the Accounts preregistered-users topic (a linked account
changes a student's displayed identity), and `Course.refresh_class_students/4`
claims the events from both.

---

## User-Facing Pages

The authenticated student pages live in [`dashboard/`](./dashboard) (plus the
profile page, documented with the
[Accounts context](../archidep/accounts/CONTRIBUTING.md#sessions)):

- **[`DashboardLive`](./dashboard/dashboard_live.ex)** (`/app`) — the home
  dashboard: it shows the credentials for the shared **SSH exercise VM** (with
  copy buttons and host-key fingerprints) and the student's active servers with
  their live state.
- **[`MyServersLive`](./dashboard/my_servers_live.ex)** (`/app/my-servers`) —
  the student's servers: register a new one (a dialog from the [server
  UI](#servers-ui)), and view/monitor each with retry actions. Both pages track
  live server state with a
  [`ServerTracker`](../archidep/servers/CONTRIBUTING.md#server-tracking) and
  react to Course/Servers PubSub updates.
- **[`WhatIsYourNameLive`](./dashboard/components/what_is_your_name_live.ex)** —
  a prompt shown on the dashboard until the student confirms their username,
  submitting through
  [`Course.configure_student`](../archidep/course/CONTRIBUTING.md#username-confirmation).

---

## Admin Console

The `/admin` pages ([`admin/`](./admin)) are the **teacher / root** console for
managing classes, students and servers and for inspecting the system. They are
ordinary authenticated live views with **no special router guard**; root access
is enforced because each page loads **root-only [context
operations][authorization]** in `mount` (the policy rejects non-root users —
e.g. `AdminLive` calls `Course.list_active_classes/1`), and the admin menu is
only shown to root users in the [`app`
layout](./components/layouts.ex). See [Authentication &
Authorization](#authentication--authorization).

The areas map directly onto the bounded contexts:

- **Overview** — [`AdminLive`](./admin/admin_live.ex) (`/admin`): the active
  [classes](../archidep/course/CONTRIBUTING.md) and the live state of their
  [servers](../archidep/servers/CONTRIBUTING.md#server-tracking), plus the
  [Ansible queue](../archidep/servers/CONTRIBUTING.md#ansible-pipeline) health.
- **Classes & students** — [`ClassesLive`](./admin/classes/classes_live.ex),
  [`ClassLive`](./admin/classes/class_live.ex) and
  [`StudentLive`](./admin/classes/student_live.ex), with dialogs for
  creating/editing/deleting classes and students, editing a class's [expected
  server
  properties](../archidep/course/CONTRIBUTING.md#expected-server-properties),
  and [importing students](../archidep/course/CONTRIBUTING.md#student-import) —
  all backed by the [Course
  context](../archidep/course/CONTRIBUTING.md#use-cases).
  [`ClassesController`](./admin/classes/classes_controller.ex) adds two `GET`
  endpoints: a class CSV export and the SSH-exercise-VM Ansible inventory.
- **Servers** — [`AdminClassServersLive`](./admin/admin_class_servers_live.ex)
  shows a class's servers; the `/admin/servers/:id` route reuses the user-facing
  [`ServerLive`](#servers-ui) with an admin scope.
- **Ansible** — [`AnsibleLive`](./admin/ansible/ansible_live.ex) and
  [`AnsiblePlaybookRunLive`](./admin/ansible/ansible_playbook_run_live.ex)
  browse [playbook runs and their
  events](../archidep/servers/CONTRIBUTING.md#ansible-pipeline).
- **Event log** — [`EventLogLive`](./admin/events/event_log_live.ex) and
  [`EventLive`](./admin/events/event_live.ex) browse the [business-event audit
  log](../../CONTRIBUTING.md#events--auditing).

These pages exercise the contexts' public APIs and subscribe to their PubSub
topics for live updates; the per-area dialogs and form components wrap the
contexts' `validate_*` / changeset functions for live form validation.

---

## Servers UI

The student-facing server pages live in [`servers/`](./servers): they register,
display and manage a student's [cloud
server](../archidep/servers/CONTRIBUTING.md) and let students retry failed setup
steps.

- **[`ServerLive`](./servers/server_live.ex)** is the server detail page. It
  serves both the student route (`/servers/:id`) and the admin route
  (`/admin/servers/:id`, with an admin scope passed via the route's `private`
  assign), showing the server's details, its [live
  state](../archidep/servers/CONTRIBUTING.md#server-tracking) and problems, and
  its [expected vs. actual
  properties](../archidep/servers/CONTRIBUTING.md#server-properties), tracked
  through a
  [`ServerTracker`](../archidep/servers/CONTRIBUTING.md#server-tracking).
- **Dialogs** — [`NewServerDialogLive`](./servers/new_server_dialog_live.ex)
  (register, opened from [My Servers](#user-facing-pages)),
  [`EditServerDialogLive`](./servers/edit_server_dialog_live.ex) and
  [`DeleteServerDialogLive`](./servers/delete_server_dialog_live.ex) — wrap the
  Servers context's [create/update/delete
  operations](../archidep/servers/CONTRIBUTING.md#use-cases).
- **Forms** — [`ServerForm`](./servers/server_form.ex) and
  [`ServerPropertiesForm`](./servers/server_properties_form.ex) (with their form
  components) validate only the basic shape and types of the input; the real
  validation lives in the context's `validate_*` functions, which live
  validation calls through to.
- **[`ServerRetryHandlers`](./servers/server_retry_handlers.ex)** are shared
  live view handlers for the retry-connecting / retry-Ansible / retry-open-ports
  actions, reused by `ServerLive` and the [dashboard pages](#user-facing-pages).
- **[`ServerComponents`](./servers/server_components.ex)** and
  **[`ServerHelpComponent`](./servers/server_help_component.ex)** render the
  server cards and the troubleshooting tips.
- **[`ServerCallbacksController`](./servers/server_callbacks_controller.ex)**
  backs the `POST /api/callbacks/servers/:id/up` route: it reads the server's
  bearer token and calls
  [`Servers.notify_server_up/2`](../archidep/servers/CONTRIBUTING.md#use-cases)
  — the server itself calls this when it comes online, with no user session.

---

## Components & Layouts

[`components/`](./components) holds the shared function components and layouts:

- **[`CoreComponents`](./components/core_components.ex)** — generic building
  blocks (data displays, note/callout boxes, etc.);
  **[`FormComponents`](./components/form_components.ex)** — form fields, errors
  and a concurrent-modification warning;
  **[`CourseComponents`](./components/course_components.ex)** — course-specific
  bits (student username badge, expected server properties).
- **[`Layouts`](./components/layouts.ex)** — the
  [`root`](./components/layouts/root.html.heex) layout (HTML skeleton, assets,
  the shared [theme](../../../theme/CONTRIBUTING.md)) and the
  [`app`](./components/layouts.ex) layout function component (the header and
  sidebar shared with the course site, the flash container, and the admin menu
  shown to root users).

---

## Notifications

User notifications (toasts) use [Flashy][flashy] and are rendered by the flash
container in the [`app` layout](./components/layouts.ex):

- **[`Notifications.Message`](./components/notifications/message.ex)** renders a
  single toast (info/success/warning/error, with an icon and optional
  auto-dismiss progress bar).
- **[`Notifications.Disconnected`](./components/notifications/disconnected.ex)**
  shows the "lost connection, reconnecting…" notice when a live view's socket
  drops.

Notifications can be triggered from controllers, live views and live components
(the `:controller`/`:live_view` macros import Flashy).

---

## Internationalization

User-facing strings go through [Gettext][gettext] with the
[`ArchiDepWeb.Gettext`](./gettext.ex) backend. Translations are formatted with
[Cldr][cldr] and [Cldr Messages][cldr-messages] (ICU message syntax): the
[`ArchiDepWeb.Cldr`](./cldr.ex) backend wires up the `Cldr.Number` and
`Cldr.Message` providers, and
[`ArchiDepWeb.Gettext.Interpolation`](./gettext/interpolation.ex) bridges the
two. Always use Gettext for user-facing text.

---

## Helpers

[`helpers/`](./helpers) provides small view/controller helpers:

- [`AuthHelpers`](./helpers/auth_helpers.ex) — login/role/impersonation checks
  (see [Authentication & Authorization](#authentication--authorization)).
- [`ConnHelpers`](./helpers/conn_helpers.ex) /
  [`SocketHelpers`](./helpers/socket_helpers.ex) — extract client metadata
  (IP/user-agent) and the per-user `live_socket_id`.
- [`DateFormatHelpers`](./helpers/date_format_helpers.ex),
  [`UserAgentFormatHelpers`](./helpers/user_agent_format_helpers.ex)
  ([UAInspector][ua-inspector]),
  [`StudentHelpers`](./helpers/student_helpers.ex) — display formatting.
- [`DialogHelpers`](./helpers/dialog_helpers.ex),
  [`FormHelpers`](./helpers/form_helpers.ex),
  [`LiveViewHelpers`](./helpers/live_view_helpers.ex) — modal dialogs, form
  param coercion, and process labels for debugging.

---

## Errors, Health & Telemetry

- **Errors** — [`ErrorHTML`](./errors/error_html.ex) renders error pages from
  the [`fallback`](./errors/html/fallback.html.heex) template (with friendly
  messages, e.g. for 404).
- **Health** — [`HealthController`](./health/health_controller.ex) backs
  `/api/health`, checking the database and the
  [Ansible pipeline](../archidep/servers/CONTRIBUTING.md#ansible-pipeline) queue
  and reporting `ok`/`degraded`/`error`.
- **Telemetry** — [`ArchiDepWeb.Telemetry`](./telemetry.ex) defines the Phoenix,
  Ecto and VM metrics surfaced by the dev [LiveDashboard][live-dashboard]
  (distinct from the Prometheus [`PromEx` metrics][app-telemetry]).

---

## Authentication & Authorization

Authentication itself (Switch edu-ID OIDC, login links, sessions, impersonation)
is implemented in, and documented with, the [Accounts
context](../archidep/accounts/CONTRIBUTING.md#authentication). The web layer
**enforces** it:

- the `:fetch_authentication` plug loads the current `auth` for browser/API
  routes;
- the [`:live_view` macro](#the-web-kernel) adds
  `on_mount(ArchiDepWeb.LiveAuth)`, so every live view requires a valid session;
  and
- [`AuthHelpers`](./helpers/auth_helpers.ex) (`logged_in?/1`, `root?/1`,
  `impersonating?/1`, `can_impersonate?/2`) gate UI and actions.

**Authorization** of business operations is done by the contexts' [policy
modules][authorization] — at the context boundary, not in the web layer. A page
is therefore restricted to root users precisely because, and to the extent that,
it calls root-only context operations, which the policy rejects for non-root
users; being routed under `/admin` or hidden from the menu is incidental, not
the guard. The pitfall to avoid is the opposite — bypassing a context (e.g.
querying the `Repo` directly) to display sensitive data, which would skip the
policy.

---

## References

- [Application documentation][app-contributing] — overall architecture,
  [bounded contexts][bounded-contexts] and [authorization][authorization]
- [Accounts context](../archidep/accounts/CONTRIBUTING.md) — authentication,
  sessions and the [web wiring](../archidep/accounts/CONTRIBUTING.md#web-wiring)
- [Course material site](../../../course/CONTRIBUTING.md) — the static site this
  layer serves and drives in [real time](#real-time-integration)
- [Phoenix LiveView][phoenix-live-view], [Flashy][flashy], [Gettext][gettext] /
  [Cldr][cldr]

[app-contributing]: ../../CONTRIBUTING.md
[authorization]: ../../CONTRIBUTING.md#authorization
[app-telemetry]: ../../CONTRIBUTING.md#telemetry
[bounded-contexts]: ../../CONTRIBUTING.md#bounded-contexts
[flashy]: https://hexdocs.pm/flashy/readme.html
[gettext]: https://hexdocs.pm/gettext/Gettext.html
[cldr]: https://hexdocs.pm/ex_cldr/readme.html
[cldr-messages]: https://hexdocs.pm/ex_cldr_messages/readme.html
[live-dashboard]: https://hexdocs.pm/phoenix_live_dashboard
[phoenix-live-view]: https://hexdocs.pm/phoenix_live_view/welcome.html
[ua-inspector]: https://hexdocs.pm/ua_inspector/readme.html
