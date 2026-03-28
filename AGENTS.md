# AGENTS.md

This file provides guidance to AI agents working with code in this repository.

## Project Overview

PhoenixKit Emails — an Elixir module for email tracking, analytics, templates, and AWS SES/SNS/SQS integration, built as a pluggable module for the PhoenixKit framework. Provides admin LiveViews for managing email logs, templates, metrics, queue, and blocklist. Implements the `PhoenixKit.Email.Provider` behaviour (14 callbacks) for unified email provider integration.

## Commands

```bash
mix test                    # Run all tests
mix test test/file_test.exs # Run single test file
mix test test/file_test.exs:42  # Run specific test by line
mix format                  # Format code
mix credo --strict          # Lint / code quality (strict mode)
mix dialyzer                # Static type checking
mix precommit               # compile + format + credo --strict + dialyzer
mix deps.get                # Install dependencies
```

## Dependencies

This is a **library**, not a standalone app. It requires a sibling `../phoenix_kit` directory (path dependency). The full dependency chain:

- `phoenix_kit` (path dep) — provides Module behaviour, Settings, RepoHelper, Dashboard tabs, Email.Provider behaviour
- `phoenix_live_view` — web framework
- `oban` — background job processing (SQS polling)
- `ex_aws`, `ex_aws_sqs`, `ex_aws_sns`, `ex_aws_sts`, `ex_aws_s3` — AWS integration
- `hammer` — rate limiting
- `nimble_csv` — CSV export
- `jason` — JSON encoding/decoding
- `saxy`, `sweet_xml` — XML parsing for AWS responses

## Architecture

This is a **PhoenixKit module** that implements the `PhoenixKit.Module` behaviour. It depends on the host PhoenixKit app for Repo, Endpoint, and Settings.

### Core Schemas (all use UUIDv7 primary keys)

- **Log** — email log record with status, recipient, subject, body, headers, provider info
- **Event** — delivery/bounce/complaint/open/click events from AWS SES
- **Template** — email templates with name, subject, body, locale support
- **EmailLogData** — structured email data for log entries

### Provider Integration

`Provider` implements `PhoenixKit.Email.Provider` (14 callbacks) — the unified email provider interface. Delegates to `Interceptor` (before/after send hooks) and `Templates` (template rendering). Registered on startup via `ApplicationIntegration.register()` which sets `:email_provider` in the application env.

### Contexts

- **Emails** (main module) — system config, log CRUD, event management, analytics/metrics, maintenance
- **Templates** — template CRUD, rendering with variable substitution, locale support
- **Interceptor** — before-send logging, after-send status updates, rate limit checks
- **Metrics** — engagement metrics, campaign stats, provider performance
- **Archiver** — cleanup old logs, compress bodies, S3 archival
- **RateLimiter** — per-recipient and global rate limiting via Hammer

### SQS Pipeline

AWS SES events flow through SQS:

1. **SQSWorker** (GenServer) — long-polling SQS queue for delivery events
2. **SQSProcessor** — parses and processes SQS messages into Event records
3. **SQSPollingJob** (Oban worker) — alternative Oban-based polling
4. **SQSPollingManager** — manages Oban polling lifecycle (enable/disable/status)

The `Supervisor` starts the SQS pipeline conditionally based on settings (`email_enabled`, `email_ses_events`, `sqs_polling_enabled`, and queue URL presence).

### Web Layer

- **Admin** (9 LiveViews): Metrics (dashboard), Emails (list), Details (single email), Templates (list), TemplateEditor (create/edit), Queue, Blocklist, Settings, EmailTracking
- **Public** (2 Controllers): `WebhookController` (AWS SNS webhook), `ExportController` (CSV/JSON export)
- **Routes**: `route_module/0` provides public routes (webhook + export); admin routes auto-generated from `admin_tabs/0`
- **Paths**: Centralized path helpers in `Paths` module — always use these instead of hardcoding URLs

### Settings Keys

All stored via PhoenixKit Settings with module `"email_system"`:

- `email_enabled` — enable/disable the entire system
- `email_save_body` — save full email body vs preview only
- `email_save_headers` — save email headers
- `email_ses_events` — enable AWS SES event processing
- `email_retention_days` — days to keep emails (default: 90)
- `aws_ses_configuration_set` — AWS SES configuration set name
- `email_compress_body` — compress body after N days
- `email_archive_to_s3` — enable S3 archival
- `email_sampling_rate` — percentage of emails to fully log
- `email_create_placeholder_logs` — create placeholder logs for orphaned events
- `sqs_polling_enabled` — enable SQS polling
- `sqs_polling_interval_ms` — polling interval

### File Layout

```
lib/
├── mix/tasks/phoenix_kit_emails.install.ex  # Install mix task
└── phoenix_kit/modules/emails/
    ├── emails.ex                    # Main module (PhoenixKit.Module behaviour)
    ├── application_integration.ex   # Provider registration on startup
    ├── provider.ex                  # PhoenixKit.Email.Provider implementation
    ├── log.ex                       # Log Ecto schema
    ├── event.ex                     # Event Ecto schema
    ├── template.ex                  # Template Ecto schema
    ├── email_log_data.ex            # EmailLogData struct
    ├── templates.ex                 # Templates context (CRUD, rendering)
    ├── interceptor.ex               # Before/after send hooks
    ├── metrics.ex                   # Analytics and engagement metrics
    ├── archiver.ex                  # Cleanup, compression, S3 archival
    ├── rate_limiter.ex              # Rate limiting via Hammer
    ├── sqs_worker.ex                # GenServer SQS long-polling
    ├── sqs_processor.ex             # SQS message parsing/processing
    ├── sqs_polling_job.ex           # Oban-based SQS polling
    ├── sqs_polling_manager.ex       # Oban polling lifecycle
    ├── supervisor.ex                # OTP Supervisor for SQS pipeline
    ├── table_columns.ex             # Column definitions for admin tables
    ├── paths.ex                     # Centralized URL path helpers
    ├── utils.ex                     # Shared utilities
    └── web/
        ├── routes.ex                # Public route generation
        ├── webhook_controller.ex    # AWS SNS webhook handler
        ├── export_controller.ex     # CSV/JSON export
        ├── metrics.ex               # Dashboard LiveView
        ├── emails.ex                # Emails list LiveView
        ├── details.ex               # Email details LiveView
        ├── templates.ex             # Templates list LiveView
        ├── template_editor.ex       # Template editor LiveView
        ├── queue.ex                 # Queue LiveView
        ├── blocklist.ex             # Blocklist LiveView
        ├── settings.ex              # Settings LiveView
        └── email_tracking.ex        # Email tracking LiveView
```

## Key Conventions

- **UUIDv7 primary keys** — all schemas use `@primary_key {:uuid, UUIDv7, autogenerate: true}` and `uuid_generate_v7()` in migrations (never `gen_random_uuid()`)
- **Oban workers** — SQS polling uses Oban workers; never spawn bare Tasks for async event processing
- **Centralized paths via `Paths` module** — never hardcode URLs or route paths in LiveViews or controllers; use `Paths` helpers or `PhoenixKit.Utils.Routes.path/1` for cross-module links
- **Admin routes from `admin_tabs/0`** — all admin navigation is auto-generated by PhoenixKit Dashboard from the tabs returned by `admin_tabs/0`; do not manually add admin routes elsewhere
- **Public routes from `route_module/0`** — the single public entry point is `Web.Routes`; `route_module/0` returns this module so PhoenixKit registers public routes automatically
- **LiveViews use `PhoenixKitWeb` `:live_view`** — this module uses `use PhoenixKitWeb, :live_view` for correct admin layout integration (sidebar/header)
- **Provider registration is automatic** — `ApplicationIntegration.register()` is called during `Supervisor.init/1`; the host app does not need to configure the provider manually
- **Settings via PhoenixKit Settings** — all config is stored in the PhoenixKit settings system, not in application env; use `Emails.get_config/0` and related functions

## Testing

### Structure

```
test/
├── test_helper.exs                          # ExUnit setup
├── phoenix_kit_emails_test.exs              # Unit tests (behaviour compliance)
└── phoenix_kit_emails_integration_test.exs  # Integration tests
```

### Running tests

```bash
mix test                                        # All tests
mix test test/phoenix_kit_emails_test.exs       # Unit tests only
mix test test/phoenix_kit_emails_integration_test.exs  # Integration tests only
```

## PR Reviews

PR reviews are stored in `dev_docs/pull_requests/` and tracked in version control.

### Structure

```
dev_docs/pull_requests/<year>/<pr_number>-<slug>/{AGENT}_REVIEW.md
```

- **`<year>`** — year the PR was created (e.g., `2026`)
- **`<pr_number>`** — GitHub PR number (e.g., `1`)
- **`<slug>`** — short kebab-case summary from the PR title (e.g., `add-emails-package`)
- **`{AGENT}_REVIEW.md`** — review file named after the reviewing agent (e.g., `CLAUDE_REVIEW.md`, `GEMINI_REVIEW.md`)

### Review file format

```markdown
# Claude's Review of PR #<number> — <title>

**Verdict:** <Approve | Approve with follow-up items | Needs Work> — <reasoning>

## Critical Issues
### 1. <title>
**File:** <path>:<lines>
<Description, code snippet, fix>

## Security Concerns
## Architecture Issues
## Code Quality
### Issues
### Positives

## Recommended Priority
| Priority | Issue | Action |
```

Severity levels: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`

When issues are fixed in follow-up commits, append `— FIXED` to the issue title.

Additional files per PR directory:
- `README.md` — PR summary (what, why, files changed)
- `FOLLOW_UP.md` — post-merge issues, discovered bugs
- `CONTEXT.md` — alternatives considered, trade-offs
