# MentorFire Demo - Build Tracker

**Spec:** [`mentorfire-demo-spec.md`](mentorfire-demo-spec.md)
**Process:** `OPEN-SOURCE-PLAYBOOK.md` steps 4-12
**Boilerplate:** open-base (scaffolded with `new-open-app.sh mentorfire "MentorFire" "..."`)

| # | Phase | Status |
|---|---|---|
| 1 | Branding and config: `.env(.example)` (timeout 45), layout fallback name, ember/blue accent CSS, landing page, base dashboard removed | `[x]` |
| 2 | Models: `MentorOffer`, `ProgramDraft` migrations, validations, constants, associations; schema rebuilt without base's stray tables | `[x]` |
| 3 | Routes and controllers: `MentorOffersController` CRUD, `ProgramDraftsController` (index redirect, rate limit, rescues) | `[x]` |
| 4 | Views and Stimulus: dashboard, form, offer page, result page (session timeline, disclaimer, Download .md, raw toggle), `generating`, `form_submit`, `download_markdown` | `[x]` |
| 5 | AI integration: `mentorfire_program_v1` prompt, parser, `ProgramRulesCheck` (session count, agenda minutes, assignee, task placement) | `[x]` |
| 6 | Seeds: template, market stall example offer with a completed draft, `demo_placeholder_v1` removed (seed, eval case, DB row) | `[x]` |
| 7 | Guardrails and evals: `config/ai_guards.yml`, `evals/cases/mentorfire_program_v1.yml` (8 cases, each hard rule mirrored) | `[x]` |
| 8 | Specs: models, `ProgramRulesCheck`, requests; `bundle exec rspec` green; `bin/rails evals:guardrails` PASS | `[x]` |
| 9 | README rewrite, UI journey manifest (port 3128), pre-publish check, local commit | `[x]` |

## Quick reference

```
mentor_offers_path                          GET  /offers   (also /dashboard)
new_mentor_offer_path                       GET  /offers/new
mentor_offer_path(o)                        GET  /offers/:id
edit_mentor_offer_path(o)                   GET  /offers/:id/edit
mentor_offer_program_drafts_path(o)         POST /offers/:id/drafts   (GET redirects to the offer)
mentor_offer_program_draft_path(o, d)       GET  /offers/:id/drafts/:id
```

```
Template:   mentorfire_program_v1   (gemini-2.5-flash, 8192 max tokens, temperature 0.5)
Variables:  subject, experience, who_its_for, sessions_count, session_minutes
JSON:       name, purpose, outcome_statement,
            sessions[= sessions_count]{number, title, aim, agenda[3-6]{item, minutes}},
            tasks[6-12]{name, session_number 0..n, assignee mentor|mentee},
            first_intro_questions[3]
Code rules: ProgramRulesCheck: session count, agenda minutes <= session length, assignee, task placement
```

## Not done here (needs the owner)

- Live runs: `bin/rails evals:run` and `./ui-journey-fleet.sh --yes open-mentorfire` (real Gemini calls), and the free `./ui-journey-fleet.sh --free open-mentorfire` (starts a server).
- `Open/README.md` app count and `git open repos.md` remote line (shared files, updated by the coordinator).
- GitHub repo creation and push.
