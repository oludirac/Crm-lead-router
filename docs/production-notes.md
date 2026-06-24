# Production Notes

This case study runs locally with n8n and Supabase. A production version would keep the same core pattern but tighten the edges around identity, credentials, approvals and error handling.

## Webhooks

Use n8n production webhook URLs for live form submissions. The `webhook-test` URL is only for local workflow testing and should not be used for a deployed client workflow.

Verify webhook signatures where the source platform supports them. Signed webhooks help confirm that the payload came from the expected form or CRM system and was not posted by an unknown third party.

Keep the `event_id` from the source system whenever possible. If the source provides a delivery ID, submission ID or event ID, store it and use it as the idempotency key.

## Idempotency and Deduplication

Use `event_id` for idempotency, not email. A repeated `event_id` means the same webhook delivery has arrived more than once and should be skipped.

Use email, domain or an existing CRM ID for contact deduplication. A repeated email with a new `event_id` should usually create a new request or opportunity, not be treated as a duplicate event.

Add database constraints for both levels:

- `lead_events.event_id` prevents processing the same webhook event twice.
- `contacts.email` prevents creating duplicate people for the same contact.
- `lead_requests.event_id` prevents the same event from creating multiple requests.

## CRM Integration

Add HubSpot only after the workflow is stable locally. The local workflow should prove that payload normalization, dedupe, request creation, classification and logging behave correctly before external CRM writes are introduced.

In production:

- Push deduplicated contacts into HubSpot Contacts.
- Push requests into HubSpot Deals or Tickets.
- Store HubSpot IDs back in Supabase for traceability.
- Add retries and clear error handling around HubSpot API calls.

## AI Classification

Use OpenAI structured outputs rather than free-text prompts. The classifier should return predictable JSON that matches a schema, so later workflow steps do not have to guess which fields exist.

The mock classifier in this case study is deterministic by design. It keeps local testing repeatable and avoids requiring an API key for the demo.

## Human Approval

Use human approval before sending email or taking external actions on behalf of a client. Slack approval is a practical first step: post the proposed action, wait for approval, then continue the workflow.

Approval is especially important when AI output is used to draft replies, prioritize leads or recommend actions.

## Logging and Monitoring

Log every important decision:

- payload received
- duplicate event skipped
- contact created or reused
- lead request created
- classification completed
- external CRM write succeeded or failed
- approval accepted or rejected

Add monitoring and alerting for failed executions. A quiet failure in a lead routing workflow means lost opportunities, so failed runs should be visible quickly.

## Credentials

Store credentials only in n8n credentials or environment variables. Do not commit Supabase credentials, OpenAI keys, HubSpot tokens, Slack tokens, SSL certificates or exported n8n credentials to the repo.

