# n8n Workflow Export

Export the n8n workflow for this case study to:

```text
workflows/dirac-crm-lead-router-v3-case-study.json
```

Before committing the export, confirm that it does not include:

- n8n credential data
- Supabase credentials
- OpenAI API keys
- HubSpot tokens
- Slack tokens
- SSL certificates or private keys

The case study currently uses a deterministic mock classifier so the workflow can be tested without an OpenAI API key.

