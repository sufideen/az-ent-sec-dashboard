# SOC Operations Guide

Daily and weekly workflow for SOC analysts using the SOC Dashboard workbook.

## Access

SOC Analysts are granted `Microsoft Sentinel Responder`, `Log Analytics Reader`, and `Workbook Reader` on the Log Analytics Workspace (via the `socAnalystsGroupObjectId` Entra ID group — see `modules/rbac.bicep`). This allows triaging and responding to incidents and running/viewing all workbooks and queries, but not modifying analytics rules or platform configuration (that requires the Security Admins group).

## Shift start checklist

1. Open **SOC Dashboard** > **Active Incidents** — review anything opened since your last shift.
2. Check **Alerts by Severity** for any unusual volume spike vs. the prior 24h baseline.
3. Review **Threat Intelligence Matches** for any new indicator hits.
4. Confirm no analytics rule shows `enabled: false` unexpectedly (Sentinel > Analytics) — this would indicate a detection gap.

## Continuous monitoring (during shift)

- Teams channel receives real-time alerts from the Action Group -> Logic App pipeline for every fired analytics rule. Triage each per [incident-response-guide.md](incident-response-guide.md).
- Use **Failed Logins** and **Suspicious Sign-ins (Impossible Travel)** tiles proactively, not just on alert — patterns often precede a scored incident.
- Use **Top Attack Sources** to identify infrastructure worth proactively blocking even before a full incident materializes.

## Weekly SOC review

1. Export **MITRE ATT&CK Mapping** tile data — identify tactics with rising alert volume, and check whether existing rules provide adequate coverage (compare against the MITRE ATT&CK matrix for gaps).
2. Review closed incidents' `Classification` breakdown (True Positive / Benign Positive / False Positive rate) — a high false-positive rate on a specific rule is a tuning signal; adjust `triggerThreshold` or add `suppressionEnabled`/entity mappings.
3. Cross-check `kql/defender/*-security-findings.kql` (VM/AKS/Storage/Key Vault) for newly unhealthy recommendations that could indicate exploitation preconditions, not just alerts.

## Query library reference

All KQL under `/kql` is written to run standalone in Log Analytics (replace the `{TimeRange}` token with a literal filter, e.g. `TimeGenerated > ago(1d)`, when running outside a workbook):

| Folder | Use case |
|---|---|
| `kql/incidents/` | Incident queue and SLA timing |
| `kql/identity/` | Sign-in, risk, and privileged-access hunting |
| `kql/defender/` | Defender for Cloud recommendation drill-down by resource type |
| `kql/compliance/` | Azure Policy and regulatory compliance posture |
| `kql/threat-intel/` | TI indicator matches and MITRE ATT&CK coverage |

## Handoff notes template

When handing off a shift, document in the team's incident tracker:

- Open incidents and current owner/status
- Any rule tuned or disabled during the shift (and why)
- Any indicator added to the TI feed
- Any escalations raised to Security Admins
