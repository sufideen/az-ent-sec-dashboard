# Incident Response Guide

How to use this platform during an active Microsoft Sentinel incident.

## 1. Triage (first 5 minutes)

1. Teams notification arrives via the alerting Logic App with severity, alert rule name, and a deep link into Sentinel.
2. Open the **SOC Dashboard** workbook > **Active Incidents** tile to confirm the incident, its severity, and current owner.
3. Assign yourself as owner in Sentinel (Incidents blade) if unowned — this stamps `Owner` for the `open-incidents.kql` / `high-severity-incidents.kql` queries and the Executive dashboard's MTTR calculation.

## 2. Investigate

Use the **SOC Dashboard**'s supporting tiles in this order:

1. **MITRE ATT&CK Mapping** — identify the tactic/technique to scope likely attacker objectives.
2. **Top Attack Sources** — pivot on the source IP(s) involved.
3. **Failed Logins** / **Suspicious Sign-ins (Impossible Travel)** — check whether the same identity shows credential-access indicators.
4. **Threat Intelligence Matches** — check if the source IP/domain matches a known indicator.
5. Run the relevant `.kql` file directly in Logs for a wider time window than the incident's default lookback, e.g.:
   ```kql
   // kql/identity/brute-force-detection.kql, widened to 7 days
   ```

## 3. Contain

Standard containment actions available from Sentinel/Entra ID (outside this repo's scope, but the platform surfaces the data needed to decide):

- Disable the affected account / revoke sessions (Entra ID).
- Block the source IP via Conditional Access named location or NSG/Firewall rule.
- For a confirmed-compromised identity, force password reset and re-check `AADRiskyUsers` state (`kql/identity/risky-users.kql`) drops the account from **atRisk**/**confirmedCompromised**.

## 4. Escalate

- **High severity, confirmed breach**: notify Security Admins group directly (they hold `Microsoft Sentinel Contributor` + `Security Admin` per `modules/rbac.bicep`) and the CISO office email receiver on the Action Group.
- Use the incident's `IncidentUrl` (surfaced by `kql/incidents/open-incidents.kql`) to share a direct link in the escalation channel.

## 5. Close out

1. Set `Classification` and `ClassificationReason` on the incident in Sentinel (True Positive / Benign Positive / False Positive) — this feeds the Executive dashboard's trend accuracy.
2. Close the incident; `ClosedTime` automatically feeds the **Mean Time To Respond** tile on the Executive dashboard on next refresh.
3. If the incident revealed a detection gap, open a PR adding/tuning a rule per [runbook.md](runbook.md#add-a-new-sentinel-analytics-rule).
4. If the incident revealed a control gap, log it against the relevant Defender for Cloud recommendation (`kql/defender/defender-recommendations.kql`) or Azure Policy assignment (`kql/compliance/azure-policy-compliance.kql`) for remediation tracking.

## Severity -> response SLA (suggested; align to your org's IR policy)

| Severity | Acknowledge | Contain | Notify |
|---|---|---|---|
| High | 15 min | 1 hour | Immediate (Teams + email + Security Admins) |
| Medium | 1 hour | 4 hours | Teams + email |
| Low | 4 hours (business hours) | 1 business day | Email digest |

## Post-incident review

Use the **Executive Dashboard**'s Incident Trend graph and MTTD/MTTR tiles to quantify the incident's detection and response timeline for the post-incident report, and `kql/incidents/high-severity-incidents.kql` for the raw per-incident timing data.
