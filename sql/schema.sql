-- Dirac Systems CRM Lead Router case study schema
-- Purpose:
-- - lead_events stores raw inbound webhook events and handles event-level idempotency.
-- - contacts stores deduplicated people/business contacts by email.
-- - lead_requests stores individual enquiries/opportunities linked to contacts.
-- - lead_event_logs stores the audit trail.

create extension if not exists pgcrypto;

create table if not exists lead_events (
  id uuid default gen_random_uuid() primary key,

  -- Event-level idempotency.
  -- Same event_id means the same webhook delivery/retry should not be processed twice.
  event_id text unique not null,

  first_name text,
  last_name text,
  email text,
  phone text,
  company_name text,
  source text default 'tally',

  status text default 'pending',
  raw_payload jsonb,
  classification jsonb,

  followup_draft text,
  hubspot_contact_id text,
  hubspot_deal_id text,
  error_message text,

  created_at timestamp default now(),
  updated_at timestamp default now(),
  approved_at timestamp,
  rejected_at timestamp
);

alter table lead_events enable row level security;

create table if not exists contacts (
  id uuid default gen_random_uuid() primary key,

  -- Contact-level deduplication.
  -- Same email means reuse the existing contact instead of creating a duplicate.
  email text unique not null,

  first_name text,
  last_name text,
  phone text,
  company_name text,

  created_at timestamp default now(),
  updated_at timestamp default now()
);

alter table contacts enable row level security;

create table if not exists lead_requests (
  id uuid default gen_random_uuid() primary key,

  -- Same event_id should never create two lead requests.
  event_id text unique not null,

  contact_id uuid references contacts(id),
  message text,
  urgency text,
  source text default 'tally',
  status text default 'pending',
  classification jsonb,

  created_at timestamp default now(),
  updated_at timestamp default now()
);

alter table lead_requests enable row level security;

create table if not exists lead_event_logs (
  id uuid default gen_random_uuid() primary key,

  event_id text not null,
  step text not null,
  status text not null,
  message text,
  metadata jsonb,

  created_at timestamp default now()
);

alter table lead_event_logs enable row level security;

create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_lead_events_updated_at on lead_events;

create trigger update_lead_events_updated_at
before update on lead_events
for each row
execute function update_updated_at_column();

drop trigger if exists update_contacts_updated_at on contacts;

create trigger update_contacts_updated_at
before update on contacts
for each row
execute function update_updated_at_column();

drop trigger if exists update_lead_requests_updated_at on lead_requests;

create trigger update_lead_requests_updated_at
before update on lead_requests
for each row
execute function update_updated_at_column();

