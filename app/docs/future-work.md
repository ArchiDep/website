# Future work

This document collects work we intend to do but have deliberately deferred —
ideas that are worth recording so they are not lost, but that are not scheduled
for the current round of changes. Each section below describes one planned task:
the problem it solves, why it is not being done now, and a sketch of the
approach so whoever picks it up has a starting point rather than a blank page.

This is a living document. Add a level-2 heading per planned task and re-run
`npm run doctoc` to update the table of contents.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Break-glass recovery for root users when Switch edu-ID is unavailable](#break-glass-recovery-for-root-users-when-switch-edu-id-is-unavailable)

<!-- END doctoc -->

## Break-glass recovery for root users when Switch edu-ID is unavailable

**Problem.** Root users authenticate through Switch edu-ID (OIDC). If the
identity provider is unreachable — an outage, a misconfiguration, or an expired
integration — there is currently no way for a root user to log in, which is
exactly when administrative access is most needed (to investigate or mitigate
the incident).

**Why not login links.** The obvious shortcut is to let a login link
authenticate a root account, but we have decided against it (see the security
invariant tracked in [`wip/testing.md`](../../wip/testing.md)). A login link is
a bearer token carried in a URL, so it leaks through browser history, proxy and
server logs, and `Referer` headers; root is the highest-privilege principal in
the system, so granting it through a channel with those properties is the wrong
trade-off. Login links are the **student** fallback path and carry that path's
looser assumptions. Break-glass recovery for root deserves its own mechanism
with its own controls rather than being bolted onto the student feature.

**Proposed approach.** Root users generally also control the server the
application runs on (shell access). We can use that fact as the proof of
authorization: a recovery credential that can only be produced by someone with
server access.

- Provide a `mix` task (run on the server) that generates a **short-lived,
  single-use token** and prints it to standard output only. Possession of the
  printed token then demonstrates control of the server.
- Expose a dedicated, clearly-labelled recovery route where a root user enters
  that token to obtain a root session — separate from the normal login flow and
  from the login-link route.
- Design the token with tight controls from the start: a short TTL (minutes),
  single use, bound specifically to a root account, rate-limited at the entry
  endpoint, and fully audited via a stored event so every break-glass login is
  visible in the audit log.

**Open questions to resolve when scheduling this.**

- Where the token is stored and validated (reuse the `login_links` table with a
  root-specific path, or a dedicated schema/table for recovery tokens).
- Whether the `mix` task targets a specific root account (by email) or mints a
  generic root recovery session.
- How the recovery route is protected against being reachable in normal
  operation (feature flag, separate pipeline, or always-on but heavily audited
  and rate-limited).
