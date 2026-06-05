# Contributing

This document describes the **Accounts bounded context** of the ArchiDep
dashboard application. It is part of the application documented in the
[`app/CONTRIBUTING.md`][app-contributing] file at the application root, which
covers the overall architecture, the general [bounded context
anatomy][bounded-contexts], coding guidelines, [authorization][authorization]
and tooling that also apply here. Read that document first.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
- [Context Structure](#context-structure)
- [Domain Model](#domain-model)
- [Authentication](#authentication)
  - [Switch edu-ID (OIDC)](#switch-edu-id-oidc)
  - [Login Links](#login-links)
  - [Web Wiring](#web-wiring)
- [Sessions](#sessions)
- [Impersonation](#impersonation)
- [Use Cases](#use-cases)
- [Business Events](#business-events)
- [Authorization](#authorization)
- [References](#references)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## Overview

The Accounts context (`ArchiDep.Accounts`, [`accounts.ex`](../accounts.ex) /
[`context.ex`](./context.ex)) is responsible for everything related to **user
identity, authentication and sessions**: registering and logging users in,
logging them out, managing their active sessions, and letting teachers
impersonate students.

Key concepts a contributor must understand:

- **Two kinds of users.** A [`UserAccount`](./schemas/user_account.ex) is either
  a **root** user (a teacher/administrator: `root: true`, no linked
  preregistered user) or a **student** (`root: false`, linked to a
  [`PreregisteredUser`](./schemas/preregistered_user.ex)). Root users are
  recognized at login from a configured list of identifiers; everyone else must
  have been preregistered.
- **Preregistration.** Students do not self-register. A
  [`PreregisteredUser`](./schemas/preregistered_user.ex) (in a
  [`UserGroup`](./schemas/user_group.ex), i.e. a class/cohort) is created ahead
  of time by the [Course context](../course.ex); on the student's first login it
  is matched by email and linked to a newly created `UserAccount`.
- **Two authentication paths.** Users normally log in with their [Switch
  edu-ID][switch-edu-id] account over OIDC. As a fallback, a root user can
  generate a one-time [login link](#login-links) for a preregistered student.
- **Sessions and impersonation.** Each login creates a
  [`UserSession`](./schemas/user_session.ex) carrying an opaque token and client
  metadata. A root user can [impersonate](#impersonation) a student, which is
  recorded on their own session.

---

## Context Structure

The context follows the standard [bounded context anatomy][bounded-contexts]:

- **Public API** — [`accounts.ex`](../accounts.ex) delegates to
  [`context.ex`](./context.ex) (which implements
  [`behaviour.ex`](./behaviour.ex)), which in turn routes each operation to a
  [use case](#use-cases). See [Use Cases](#use-cases) for the operations and the
  module that implements each.
- **Types** — [`types.ex`](./types.ex) (e.g. the Switch edu-ID login data).
- **Schemas** — [`schemas/`](./schemas), see [Domain Model](#domain-model).
- **Use cases** — [`use_cases/`](./use_cases), see [Use Cases](#use-cases).
- **Policy** — [`policy.ex`](./policy.ex), see [Authorization](#authorization).
- **Events** — [`events/`](./events), see [Business Events](#business-events).
- **PubSub** — [`pub_sub.ex`](./pub_sub.ex) broadcasts
  `{:preregistered_user_updated, preregistered_user}` on per-user and
  per-user-group topics so live views can react to preregistration changes.

---

## Domain Model

The context's schemas and the database tables they back:

- [`UserAccount`](./schemas/user_account.ex) (`user_accounts`): A registered
  account that can log in (root or student). Tracks `username`, `root`,
  `active`, and links to its Switch edu-ID identity and preregistered user.
- [`Identity.SwitchEduId`](./schemas/identity/switch_edu_id.ex)
  (`switch_edu_ids`): The Switch edu-ID OIDC identity (unique
  `swiss_edu_person_unique_id`, name) linked to an account; created/updated on
  each OIDC login.
- [`UserSession`](./schemas/user_session.ex) (`user_sessions`): An active login
  session: opaque token, client IP/user-agent, timestamps, and the optional
  `impersonated_user_account_id`.
- [`LoginLink`](./schemas/login_link.ex) (`login_links`): A one-time, single-use
  [login link](#login-links) token for a preregistered student.
- [`PreregisteredUser`](./schemas/preregistered_user.ex) (`students`): A student
  record created before first login; matched by email and linked to a
  `UserAccount`.
- [`UserGroup`](./schemas/user_group.ex) (`classes`): A cohort/class grouping
  preregistered students, with an `active` flag and an optional start/end date
  window.

> **Cross-context note.** `PreregisteredUser` and `UserGroup` are backed by the
> `students` and `classes` tables — the same tables the [Course
> context](../course.ex) owns for class/student management. The Accounts context
> uses its own schemas as authentication-focused views of that data (mirroring
> the `UserAccount` vs. `Servers.ServerOwner` example in the [application
> docs][bounded-contexts]). When changing those tables, consider both contexts.

A student account can only log in while it is **active**: the account, its
linked preregistered user, _and_ that user's group must all be active (the group
also respects its optional start/end date window). Disabling a `UserGroup` thus
disables every student in it.

---

## Authentication

### Switch edu-ID (OIDC)

The primary login path uses [Switch edu-ID][switch-edu-id] via
[Ueberauth][ueberauth] and the [Ueberauth OIDC][ueberauth-oidcc] strategy
(OpenID Connect). The OIDC provider is configured under the `switch_edu_id`
Ueberauth provider in [`config/config.exs`](../../../config/config.exs).

The [`LogInOrRegisterWithSwitchEduId`](./use_cases/log_in_or_register_with_switch_edu_id.ex)
use case drives the flow on the callback:

1. Create or update the [`SwitchEduId`](./schemas/identity/switch_edu_id.ex)
   identity from the OIDC claims (keyed on `swiss_edu_person_unique_id`).
2. Decide whether this is a **root** login (the identity or one of its emails is
   in the configured root-user list) or a **student** login (exactly one active,
   unlinked `PreregisteredUser` matches one of the emails). Zero or multiple
   matches are rejected with `:unauthorized_switch_edu_id`.
3. Create the account on first login (or relink an existing inactive account to
   a new preregistration, e.g. a student repeating the year in a new class).
4. Create a [session](#sessions) and record a
   [`UserRegisteredWithSwitchEduId`](./events/user_registered_with_switch_edu_id.ex)
   or
   [`UserLoggedInWithSwitchEduId`](./events/user_logged_in_with_switch_edu_id.ex)
   event.

### Login Links

When Switch edu-ID is not usable, a root user can generate a **one-time login
link** for a preregistered student with
[`CreateLoginLinks`](./use_cases/create_login_links.ex)
(`create_login_link_for_preregistered_user/2`). Generating a new link
deactivates any previous links for that student and records a
[`PreregisteredUserLoginLinkCreated`](./events/preregistered_user_login_link_created.ex)
event.

Following the link triggers
[`LogInOrRegisterWithLink`](./use_cases/log_in_or_register_with_link.ex), which
validates the token ([`LoginLink`](./schemas/login_link.ex), valid while
`active` and unused), creates the account if needed, starts a session, marks the
link as used, and records a
[`UserRegisteredWithLink`](./events/user_registered_with_link.ex) or
[`UserLoggedInWithLink`](./events/user_logged_in_with_link.ex) event.

### Web Wiring

Although authentication is the Accounts domain, the HTTP/LiveView wiring lives
in the web layer:

- [`ArchiDep.Authentication`](../authentication.ex) — the struct representing
  the currently authenticated session (`principal_id`, `username`, `root`,
  `session_id`, `session_token`, `session_expires_at`, `impersonated_id`). It is
  the value passed as `auth` into context functions and authorization policies.
- [`ArchiDepWeb.Auth.AuthController`](../../archidep_web/auth/auth_controller.ex)
  — the entry point for auth actions: the Switch edu-ID OIDC
  `request`/`callback`, the login-link login, logout, CSRF and live-socket token
  generation, and starting/stopping [impersonation](#impersonation). Routes are
  defined in [`router.ex`](../../archidep_web/router.ex) (`/login`, `/auth/...`,
  `/logout`).
- [`ArchiDepWeb.Auth`](../../archidep_web/auth.ex) — session/cookie plugs:
  `log_in/2`, `log_out/2`, `fetch_authentication/2` (loads `auth` from the
  session token or the signed `_archidep_remember_me` cookie, valid 60 days) and
  `redirect_if_user_is_authenticated/2`.
- [`ArchiDepWeb.LiveAuth`](../../archidep_web/live_auth.ex) — the live-view
  `on_mount` hook that validates the session token and assigns `auth`. It is
  attached to every live view through `on_mount(ArchiDepWeb.LiveAuth)` in the
  `live_view` macro of [`archidep_web.ex`](../../archidep_web.ex) (not via the
  router's `live_session`). It also pushes an `"authenticated"` event carrying
  [`ClientSessionData`](../../archidep_web/client_session_data.ex) to the
  browser.
- [`ArchiDepWeb.Helpers.AuthHelpers`](../../archidep_web/helpers/auth_helpers.ex)
  — view/controller helpers: `logged_in?/1`, `root?/1`, `impersonating?/1`,
  `can_impersonate?/2`, etc.

The live socket is authenticated separately: the client fetches a short-lived
(`5 min`) [`Phoenix.Token`](../../archidep_web/auth/auth_controller.ex) from
`/auth/socket` and presents it when connecting.

---

## Sessions

A [`UserSession`](./schemas/user_session.ex) is created on every login. Sessions
carry an opaque token and the client IP and user-agent, and are **valid for 30
days** from creation. The optional "remember me" cookie (see [Web
Wiring](#web-wiring)) persists for 60 days. Token and session-id validation, the
`used_at`/metadata refresh, and listing of active sessions are implemented in
the [`Sessions`](./use_cases/sessions.ex) use case.

Users can review and revoke their own sessions from the profile page
([`ProfileLive`](../../archidep_web/profile/profile_live.ex) and the
[`CurrentSessionsLive`](../../archidep_web/profile/current_sessions_live.ex)
component), which highlights the current session and ones expiring soon.
Revocation goes through [`DeleteSession`](./use_cases/delete_session.ex) (a user
may delete their own sessions; a root user may delete any), and broadcasts a
disconnect so the affected live socket is dropped.

---

## Impersonation

A root user (teacher) can **impersonate** a student to see the application
exactly as that student would, then stop at any time to return to their own
account. Impersonation is recorded on the root user's own
[`UserSession`](./schemas/user_session.ex) via its
`impersonated_user_account_id`; while set, `UserSession.authentication/1`
resolves the **principal** to the impersonated user, so all downstream
authorization uses the student's identity.

- [`Impersonate`](./use_cases/impersonate.ex) implements both
  `impersonate/2` (start) and `stop_impersonating/1` (stop).
- The [Policy](#authorization) allows a root user to impersonate anyone but
  themselves, and only allows stopping while currently impersonating.
- In the web layer, `/auth/impersonate` and `/auth/stop-impersonating` (see
  [`AuthController`](../../archidep_web/auth/auth_controller.ex)) trigger these
  and disconnect the previous live socket;
  [`AuthHelpers.can_impersonate?/2`](../../archidep_web/helpers/auth_helpers.ex)
  gates the UI.

---

## Use Cases

Each public operation of the context is implemented by a focused use case module
under [`use_cases/`](./use_cases). The operation name is the public function
exposed by [`accounts.ex`](../accounts.ex):

- [`LogInOrRegisterWithSwitchEduId`](./use_cases/log_in_or_register_with_switch_edu_id.ex)
  — `log_in_or_register_with_switch_edu_id/2`: the Switch edu-ID OIDC
  login/registration flow (see [Switch edu-ID](#switch-edu-id-oidc)).
- [`LogInOrRegisterWithLink`](./use_cases/log_in_or_register_with_link.ex) —
  `log_in_or_register_with_link/2`: the login-link login/registration flow (see
  [Login Links](#login-links)).
- [`CreateLoginLinks`](./use_cases/create_login_links.ex) —
  `create_login_link_for_preregistered_user/2`: generate a one-time login link
  for a preregistered student, root only (see [Login Links](#login-links)).
- [`Sessions`](./use_cases/sessions.ex) — `validate_session_token/2`,
  `validate_session_id/2`, `fetch_active_sessions/1`, `user_account/1`: session
  validation, metadata refresh and queries (see [Sessions](#sessions)).
- [`Impersonate`](./use_cases/impersonate.ex) — `impersonate/2`,
  `stop_impersonating/1`: start/stop impersonation (see
  [Impersonation](#impersonation)).
- [`LogOut`](./use_cases/log_out.ex) — `log_out/1`: log out of the current
  session.
- [`DeleteSession`](./use_cases/delete_session.ex) — `delete_session/2`: delete a
  specific session.

---

## Business Events

Following the application's [event-logging convention][bounded-contexts], every
significant action is persisted (in the same `Ecto.Multi` as the action) as a
business event under [`events/`](./events). Account events are written to the
user's `accounts:user-accounts:{id}` stream; the login-link-created event is
written to the preregistered user's stream.

- [`UserRegisteredWithSwitchEduId`](./events/user_registered_with_switch_edu_id.ex)
  / [`UserLoggedInWithSwitchEduId`](./events/user_logged_in_with_switch_edu_id.ex)
- [`UserRegisteredWithLink`](./events/user_registered_with_link.ex) /
  [`UserLoggedInWithLink`](./events/user_logged_in_with_link.ex)
- [`UserLoggedOut`](./events/user_logged_out.ex)
- [`SessionDeleted`](./events/session_deleted.ex)
- [`PreregisteredUserLoginLinkCreated`](./events/preregistered_user_login_link_created.ex)

---

## Authorization

The context's [`Policy`](./policy.ex) implements the application-wide
[`ArchiDep.Policy` behaviour][authorization]. Its main rules: root users may do
anything except impersonate themselves; any authenticated user may list and
delete their own sessions; a user may only stop impersonating while currently
impersonating. See the [Authorization section][authorization] of the application
documentation for how policies are invoked.

---

## References

- [Switch edu-ID][switch-edu-id] and its [OIDC integration][switch-edu-id-oidc]
- [Ueberauth][ueberauth] and the [Ueberauth OIDC][ueberauth-oidcc] strategy
- [Application documentation][app-contributing] — overall architecture,
  [bounded context anatomy][bounded-contexts] and [authorization][authorization]

[app-contributing]: ../../../CONTRIBUTING.md
[authorization]: ../../../CONTRIBUTING.md#authorization
[bounded-contexts]: ../../../CONTRIBUTING.md#bounded-contexts
[switch-edu-id]: https://eduid.ch/
[switch-edu-id-oidc]: https://help.switch.ch/eduid/docs/services/openid-connect/
[ueberauth]: https://github.com/ueberauth/ueberauth
[ueberauth-oidcc]: https://hexdocs.pm/ueberauth_oidcc/readme.html
