# CRM Lead Router Case Study

This repository documents a practical CRM lead routing automation built with n8n and Supabase.

The point of the demo is not to show a flashy AI step. It is to show the parts of lead automation that usually decide whether a workflow is useful in a real workplace: duplicate webhook handling, contact deduplication, repeat enquiry history, structured classification and audit logging.

This is a case study, not a SaaS product.

## Workplace Case Study

In a real service business, inbound enquiries do not arrive as neat CRM records.

They come from forms, calls, emails, referrals and manual notes. Some payloads are incomplete. Some field names change. Some contacts enquire more than once. Some webhook providers retry deliveries. If the workflow treats all repeated data as a duplicate, real enquiries get lost. If it treats every submission as new, the CRM fills up with duplicate contacts.

The practical workplace problem was the gap between lead capture and CRM hygiene:

- webhook retries could create duplicate records
- repeat enquiries from the same person needed to be kept as new requests
- form payloads were inconsistent enough to need normalization
- staff needed a clear trail of what happened to each lead
- manual re-keying created extra admin and follow-up risk
- CRM/contact records needed to stay clear enough for sales activity

A production-grade version of this pattern was deployed in a real company. That production build was separate from this public demo, but the operating goal was the same: reduce repetitive admin handling, keep CRM records healthier, reduce routine deduplication work, and help the team spend more time on revenue-driving follow-up.

No specific time savings or revenue claims are made here. The repo is meant to show the pattern and the engineering decisions clearly.

## The Core Distinction

This demo separates two ideas that are often mixed together.

Repeated webhook event:
Same `event_id`. This is the same delivery or retry, so the system skips it and logs `duplicate_event`.

Repeat customer with a new enquiry:
Same `email`, different `event_id`. This is not a duplicate event. The system reuses the existing contact and creates a new `lead_request`.

That distinction is the main case study.

## Tool Theory

A lead routing tool like this should sit between messy inbound lead sources and the CRM.

At scale, the workflow should:

1. Receive inbound lead events from forms, ads, landing pages or manual intake.
2. Preserve the raw payload for traceability.
3. Normalize names, email, phone, company, message, source and request context.
4. Use an event-level idempotency key so webhook retries do not create duplicate work.
5. Use contact-level deduplication so the CRM does not fill with repeated people.
6. Store each new enquiry as a separate request or opportunity.
7. Classify the request into structured fields that downstream systems can trust.
8. Log important decisions so failures can be investigated.
9. Send approved, structured data into CRM, Slack, email or reporting systems.

The important engineering point is that idempotency and deduplication solve different problems. `event_id` protects the workflow from repeated deliveries. `email` protects the CRM from duplicate contacts. Request history protects the business from losing repeat enquiries.

## Demo Implementation

This repo is a local portfolio/demo implementation of that pattern.

It currently uses:

- n8n local workflow
- Supabase Postgres
- PowerShell tests that post to an n8n webhook
- deterministic mock classification inside n8n
- audit logging in Supabase

It does not currently include:

- live HubSpot integration
- live OpenAI integration
- Slack approval
- production webhook signature verification
- queue-based retries
- monitoring or alerting
- production credential exports

That boundary is deliberate. The demo proves the core CRM behavior before adding external systems.

## Architecture

```text
Webhook
  -> Normalize payload
  -> Insert raw event
  -> Check duplicate event_id
  -> Upsert contact by email
  -> Create lead request
  -> Classify request
  -> Update request/event
  -> Write audit log
  -> Respond
```

## Data Model

- `lead_events` stores raw webhook events and handles event-level idempotency.
- `contacts` stores deduplicated people or business contacts by email.
- `lead_requests` stores individual enquiries linked to contacts.
- `lead_event_logs` stores the audit trail.

The schema is in `sql/schema.sql`.

## Test Scenarios

1. New contact and new request
   - `event_id`: `test-003`
   - `email`: `sarah@example.com`
   - Expected: contact created, lead request created, request classified.

2. Duplicate webhook retry
   - `event_id`: `test-003` again
   - `email`: `sarah@example.com`
   - Expected: no new contact, no new request, `duplicate_event` logged.

3. Existing contact, new request
   - `event_id`: `test-004`
   - `email`: `sarah@example.com`
   - Expected: same contact reused, second `lead_request` created, request classified.

## PowerShell Test

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:5678/webhook-test/lead-router-intake" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{
    "event_id": "test-003",
    "first_name": "Sarah",
    "last_name": "Jones",
    "email": "sarah@example.com",
    "phone": "+447111111111",
    "company_name": "Jones Plant Hire",
    "message": "We need help automating missed-call follow-up and website enquiries.",
    "urgency": "high",
    "heard_about_us": "Website"
  }'
```

Expected response:

```json
{
  "ok": true,
  "event_id": "test-003",
  "status": "processed",
  "message": "Lead event processed, contact deduped, request created, and classification logged"
}
```

Run the same command again with `event_id` `test-003`.

Expected duplicate response:

```json
{
  "ok": true,
  "event_id": "test-003",
  "status": "duplicate_event",
  "message": "Duplicate webhook event_id skipped"
}
```

Now send a new request from the same contact:

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:5678/webhook-test/lead-router-intake" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{
    "event_id": "test-004",
    "first_name": "Sarah",
    "last_name": "Jones",
    "email": "sarah@example.com",
    "phone": "+447111111111",
    "company_name": "Jones Plant Hire",
    "message": "We now need website enquiry routing into our CRM as well.",
    "urgency": "medium",
    "heard_about_us": "Existing contact"
  }'
```

Expected database result:

- `contacts` still has one Sarah row.
- `lead_requests` has two rows linked to Sarah.
- `lead_event_logs` includes `request_classified` and `duplicate_event` entries.

## Why the Classifier Is Mocked

The demo uses a deterministic mock classifier inside n8n so it can be tested without requiring an OpenAI API key.

In production, this node would be replaced with OpenAI structured outputs using the same JSON schema:

```json
{
  "intent": "automation | website | seo | other",
  "urgency": "low | medium | high",
  "company_size_estimate": "solo | small | medium | unknown",
  "qualification_score": 1,
  "summary": "Short summary of the request",
  "recommended_action": "call | email | nurture | disqualify"
}
```

The downstream workflow should receive predictable JSON, not free text that has to be guessed at later.

## Production Upgrade Path

A production version would keep the same event/contact/request model and add:

- production n8n webhook URL instead of `webhook-test`
- signed webhook verification where supported
- HubSpot Contact creation or update
- HubSpot Deal or Ticket creation from `lead_requests`
- Slack human approval before external email is sent
- OpenAI structured outputs instead of the mock classifier
- retry and error handling around external APIs
- monitoring for failed executions
- secure credential storage in n8n credentials or environment variables

The demo stops before those integrations so the core CRM behavior is easy to inspect.

## Repo Contents

```text
README.md
.env.example
.gitignore
docs/
  known-failure-points.md
  production-notes.md
sql/
  schema.sql
workflows/
  dirac-crm-lead-router-v3-case-study.json
  README.md
```

Do not commit Supabase credentials, OpenAI keys, HubSpot tokens, Slack tokens, SSL certificates or n8n credential exports.

