# Executive Reporting Guide

How to read and present the **Executive Security Dashboard** workbook to leadership/board audiences.

## Access

Executives are granted `Microsoft Sentinel Reader` and `Workbook Reader` (read-only) on the Log Analytics Workspace via the `executivesGroupObjectId` Entra ID group. They can view every dashboard but cannot modify rules, workbooks, or data.

## Dashboard sections and what they mean

| Tile | What it shows | What "good" looks like |
|---|---|---|
| Microsoft Secure Score | Tenant-wide Entra ID / M365 security posture | Trending toward 100%, or your org's defined target band |
| Defender Secure Score | Cloud workload security posture (Defender for Cloud) | Trending upward; investigate any month-over-month drop |
| Open Incidents | Currently unresolved Sentinel incidents | Low and stable relative to alert volume |
| Critical Incidents | Open incidents at High severity | As close to zero as possible; any sustained non-zero value warrants a briefing |
| Mean Time To Detect (MTTD) | Average time between first malicious activity and incident creation | Lower is better; track trend, not just the point value |
| Mean Time To Respond (MTTR) | Average time from incident creation to closure | Should track against your IR SLA policy (see incident-response-guide.md) |
| Compliance Status | Defender for Cloud recommendation health by severity | High-severity findings should trend toward 0% unhealthy |
| Secure Score Trend | Daily Secure Score over the selected window | Use to demonstrate ROI of security investments over a quarter |
| Incident Trend by Severity | New incidents per day, stacked by severity | Correlate spikes with known events (e.g. a new CVE, a phishing campaign) |

## Suggested cadence

- **Weekly**: SOC lead reviews with the security manager (operational detail).
- **Monthly**: Security manager presents Executive Dashboard export to leadership (trend-focused, 15 minutes).
- **Quarterly**: CISO presents Secure Score trend + compliance posture to the board/audit committee, tying tiles to the cost estimates in [cost-estimates.md](cost-estimates.md) as an ROI narrative.

## Exporting for a board deck

1. Open the workbook in the Azure Portal, set the time range to the reporting period.
2. Use the workbook's **Export to Excel/PDF/PNG** options on each tile (Pin to dashboard or Export via the "..." menu on each visual), or take a full-page screenshot for slide embedding.
3. Pair the exported visuals with the narrative from the MTTD/MTTR and Incident Trend tiles — leadership audiences respond best to trend direction plus one headline number, not raw counts.

## Talking points library

- **"Are we more secure than last quarter?"** -> Secure Score Trend tile, compare start vs. end of period.
- **"How fast do we catch things?"** -> MTTD tile, plus the Incident Trend tile to show volume context.
- **"Are we compliant?"** -> Compliance Status tile, drill into `kql/compliance/azure-policy-compliance.kql` for the specific non-compliant policy assignments if pressed for detail.
- **"What's our biggest risk right now?"** -> Critical Incidents tile + a one-line summary of the top open High-severity incident (pull `Title` from `kql/incidents/high-severity-incidents.kql`).
