# Operations Runbook

Day-2 operational procedures for this platform. For active-incident procedures, see [incident-response-guide.md](incident-response-guide.md).

## Add a new Sentinel Analytics Rule

1. Write and validate the KQL in Log Analytics (Sentinel > Logs), save a copy under `kql/<category>/<name>.kql` with the standard header comment.
2. Add an entry to the `analyticsRules` array in `bicep/main.bicep` (adapt the query to use `ago()` instead of the `{TimeRange}` workbook macro — see the note in `main.bicep` above that array).
3. Run `az bicep build --file bicep/main.bicep` locally, then open a PR — `what-if.yml` will show the new rule being created.
4. After merge and Dev deployment, verify the rule fired correctly in Sentinel > Analytics before promoting to Test/Prod.

## Update a Workbook

1. Edit the JSON in `/workbooks/*.json` directly, **or** make the change in the Azure Portal workbook editor, then use "Advanced Editor" > copy the JSON back into the repo file (strip the `x-ms-metadata` editor cruft if present).
2. Validate JSON: `python3 -m json.tool workbooks/executive-security-dashboard.json`.
3. PR + deploy. `workbook.bicep` deploys with a **stable GUID name** derived from `guid(workspaceId, '<dashboard-key>')`, so redeploying updates the existing workbook in place rather than creating a duplicate.

## Rotate the Teams webhook

1. Generate a new incoming webhook URL in Teams (Channel > Connectors > Incoming Webhook > Configure > regenerate, or delete/recreate).
2. `az keyvault secret set --vault-name <kv-name> --name teams-webhook-url --value "<new-url>"` — no redeploy needed, the Logic App reads the secret at runtime on every trigger.
3. Send a test alert (see below) to confirm delivery.

## Send a test alert

```bash
az monitor action-group test-notifications create \
  --resource-group <rg> \
  --action-group-name ag-itsolutions-secops-<env>-eus-001 \
  --notification-type logicapp \
  --receivers teamsAlerting
```

Or trigger one of the Scheduled Analytics Rules manually from Sentinel > Analytics > Run query now.

## Add/remove an RBAC persona member

Persona membership is managed in Entra ID (add/remove users from the SOC Analysts / Security Admins / Executives / Auditors groups) — **no redeployment required**, since RBAC is group-based. Only redeploy if you are changing which **roles** a persona group holds (edit `bicep/main.bicep`'s `rbac` module block).

## Onboard a new environment (e.g. a second region)

1. Copy `bicep/params/prod.bicepparam` to `bicep/params/prod-<region>.bicepparam`, adjust `location`, `regionCode`, `instance`.
2. Add a matching stage/job to the CI/CD pipeline.
3. Deploy — resource names are automatically disambiguated via the `instance`/`regionCode` naming variables.

## Key Vault soft-delete recovery

If the Key Vault or a secret is accidentally deleted:

```bash
az keyvault recover --name <kv-name>
# or for a single secret:
az keyvault secret recover --vault-name <kv-name> --name teams-webhook-url
```

Purge protection is enabled, so deletions are always recoverable within the retention window (30 days dev, 90 days test/prod).

## Common troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Teams messages not arriving | Secret not populated, or Logic App run failed on the Key Vault HTTP step | Check Logic App run history; confirm `Key Vault Secrets User` role assignment exists on the identity |
| Workbook shows "no data" | Wrong `sourceId` / workspace parameter, or the table isn't ingesting (e.g. `AADUserRegistrationDetails` requires the Entra ID diagnostic connector) | Confirm the underlying table has recent data via Logs |
| Analytics rule not creating incidents | `enabled: false`, or `incidentConfiguration.createIncident` toggled off, or query genuinely returning 0 rows | Run the query manually in Logs with the same `ago()` window |
| Deployment fails with role assignment conflict | Role assignment GUID collision from a prior partial deployment | The `guid()` seed is deterministic — this indicates the assignment already exists; safe to ignore (idempotent) or delete the stale assignment first |
