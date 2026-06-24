# Known Failure Points

This demo focuses on the places where CRM automation projects usually break.

## 1. Duplicate Webhook Retries

Form tools and webhook senders often retry requests. Without event-level idempotency, one real enquiry can become two CRM records. This demo uses `event_id` to detect and skip repeated webhook deliveries.

## 2. Contact Duplication

The same person may submit more than one form. Creating a new contact every time makes the CRM messy. This demo uses `email` to reuse an existing contact.

## 3. Repeat Enquiries Mistaken for Duplicates

A repeated email is not always a duplicate. The same contact may have a new project, new urgency or new message. This demo creates a new `lead_request` when the email already exists but the `event_id` is new.

## 4. Messy Payloads

Real form payloads are inconsistent. Field names, optional values and source-specific metadata need to be normalized before the data reaches the CRM.

## 5. Unstructured AI Output

Free-text AI output is hard to use reliably in downstream automation. This demo uses a mock structured classifier so the rest of the workflow can depend on predictable JSON fields.

## 6. AI Acting Without Human Approval

AI-generated actions should not automatically email clients or update important external systems without control points. A production version should add human approval, such as Slack approval, before external email is sent.

## 7. No Audit Trail

When something goes wrong, it should be possible to see what happened. This demo writes audit logs for important workflow decisions.

## 8. Credentials and Secrets Leaking Into the Repo

Automation repos can accidentally expose API keys, tokens, database passwords or certificate files. This repo keeps credentials out of version control and uses `.env.example` only for placeholder values.

