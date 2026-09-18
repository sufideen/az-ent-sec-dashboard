const pptxgen = require("pptxgenjs");
const { iconPng, fa } = require("./icons.js");

// ---- palette: "Midnight Executive" ----
const NAVY = "1E2761";
const NAVY_DARK = "151B4A";
const ICE = "CADCFC";
const ACCENT = "00D9C0";
const WHITE = "FFFFFF";
const INK = "1A1A2E";
const MUTED = "5C6B8A";
const CARD_LIGHT = "F4F7FE";
const RED = "E4572E";

async function main() {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE"; // 13.33 x 7.5in
  const W = 13.33, H = 7.5;

  // ---- pre-render icons ----
  const icon = {};
  const need = [
    ["cloud", fa.FaCloud, WHITE],
    ["cloudNavy", fa.FaCloud, NAVY],
    ["lock", fa.FaLock, ACCENT],
    ["server", fa.FaServer, ACCENT],
    ["cubes", fa.FaCubes, ACCENT],
    ["branch", fa.FaCodeBranch, ACCENT],
    ["shield", fa.FaShieldAlt, ACCENT],
    ["key", fa.FaKey, ACCENT],
    ["network", fa.FaNetworkWired, ACCENT],
    ["check", fa.FaCheckCircle, ACCENT],
    ["checkWhite", fa.FaCheckCircle, WHITE],
    ["warn", fa.FaExclamationTriangle, RED],
    ["warnWhite", fa.FaExclamationTriangle, ACCENT],
    ["book", fa.FaBook, ACCENT],
    ["building", fa.FaBuilding, ACCENT],
    ["chart", fa.FaChartLine, ACCENT],
    ["sync", fa.FaSyncAlt, ACCENT],
    ["database", fa.FaDatabase, ACCENT],
    ["userShield", fa.FaUserShield, ACCENT],
    ["globe", fa.FaGlobe, ACCENT],
    ["sitemap", fa.FaSitemap, ACCENT],
    ["github", fa.FaGithub, WHITE],
    ["gateway", fa.FaFilter, ACCENT],
    ["namespace", fa.FaFolder, ACCENT],
    ["scale", fa.FaExpandArrowsAlt, ACCENT],
    ["policy", fa.FaBan, ACCENT],
    ["cert", fa.FaCertificate, ACCENT],
    ["magnify", fa.FaSearch, ACCENT],
  ];
  for (const [name, comp, color] of need) {
    icon[name] = await iconPng(comp, color, 256);
  }

  const iconCircle = (slide, iconKey, x, y, d, bg, iconScale = 0.55) => {
    slide.addShape("ellipse", { x, y, w: d, h: d, fill: { color: bg }, line: { type: "none" } });
    const isz = d * iconScale;
    slide.addImage({ data: icon[iconKey], x: x + (d - isz) / 2, y: y + (d - isz) / 2, w: isz, h: isz });
  };

  const footer = (slide, pageNum, dark = false) => {
    slide.addText("Secure Kubernetes on Azure — Portfolio Showcase", {
      x: 0.5, y: H - 0.42, w: 8, h: 0.3, fontSize: 9, color: dark ? "8891C0" : MUTED, fontFace: "Calibri",
    });
    slide.addText(String(pageNum), {
      x: W - 1, y: H - 0.42, w: 0.5, h: 0.3, fontSize: 9, color: dark ? "8891C0" : MUTED, fontFace: "Calibri", align: "right",
    });
  };

  // ======================================================================
  // Slide 1 — Title
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: NAVY };
    iconCircle(s, "cloud", W / 2 - 0.55, 0.65, 1.1, NAVY_DARK, 0.55);
    s.addText("SECURE KUBERNETES ON AZURE", {
      x: 0.8, y: 2.15, w: W - 1.6, h: 1.1, fontSize: 40, bold: true, color: WHITE,
      align: "center", fontFace: "Cambria", isTextBox: true,
    });
    s.addText("A private AKS platform — designed, deployed, broken, diagnosed,\nand fixed end-to-end on real Azure infrastructure", {
      x: 1.3, y: 3.35, w: W - 2.6, h: 0.9, fontSize: 17, color: ICE,
      align: "center", fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.25,
    });
    s.addShape("rect", { x: W / 2 - 1.7, y: 4.55, w: 3.4, h: 0.55, fill: { color: NAVY_DARK }, line: { color: ACCENT, width: 1 }, rectRadius: 0.28 });
    s.addText("DEV + PROD  ·  BOTH VERIFIED LIVE", {
      x: W / 2 - 1.7, y: 4.55, w: 3.4, h: 0.55, fontSize: 11, bold: true, color: ACCENT,
      align: "center", valign: "middle", fontFace: "Calibri", isTextBox: true, charSpacing: 1,
    });
    s.addText("Sufyan Deen-Gabisi   ·   github.com/sufideen/az-ent-sec-dashboard", {
      x: 0.8, y: H - 0.75, w: W - 1.6, h: 0.4, fontSize: 11, color: "8891C0",
      align: "center", fontFace: "Calibri", isTextBox: true,
    });
  }

  // ======================================================================
  // Slide 2 — Executive Summary
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    s.addText("What This Is", { x: 0.6, y: 0.45, w: 8, h: 0.7, fontSize: 32, bold: true, color: INK, fontFace: "Cambria", isTextBox: true });
    s.addText(
      "A containerized web application running on a private Azure Kubernetes Service cluster, fronted by a " +
      "WAF-enabled Application Gateway, backed by a private container registry, deployed through OIDC-authenticated " +
      "GitHub Actions CI/CD — with zero long-lived credentials anywhere in the pipeline.",
      { x: 0.6, y: 1.25, w: 12.1, h: 0.9, fontSize: 14.5, color: MUTED, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.25 }
    );

    const stats = [
      ["cloud", "2", "Independent\nenvironments"],
      ["lock", "0", "Stored credentials\nin the pipeline"],
      ["server", "PRIVATE", "API server —\nno public IP"],
      ["warn", "5-LAYER", "Real incident,\ndiagnosed live"],
    ];
    const cardW = 2.85, gap = 0.28, startX = (W - (cardW * 4 + gap * 3)) / 2, cardY = 2.55, cardH = 2.55;
    stats.forEach(([ic, big, label], i) => {
      const x = startX + i * (cardW + gap);
      s.addShape("roundRect", { x, y: cardY, w: cardW, h: cardH, fill: { color: CARD_LIGHT }, line: { type: "none" }, rectRadius: 0.12,
        shadow: { type: "outer", color: "1E2761", opacity: 0.12, blur: 6, offset: 3, angle: 90 } });
      iconCircle(s, ic, x + cardW / 2 - 0.4, cardY + 0.35, 0.8, NAVY);
      s.addText(big, { x: x + 0.1, y: cardY + 1.3, w: cardW - 0.2, h: 0.55, fontSize: 22, bold: true, color: NAVY, align: "center", fontFace: "Cambria", isTextBox: true });
      s.addText(label, { x: x + 0.15, y: cardY + 1.85, w: cardW - 0.3, h: 0.6, fontSize: 11.5, color: MUTED, align: "center", fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.1 });
    });

    s.addText("Both environments verified end-to-end as of 2026-09-18 — real pods, real TLS, real public IP, real HTTP 200.", {
      x: 0.6, y: 5.55, w: 12.1, h: 0.5, fontSize: 12.5, italic: true, color: NAVY, fontFace: "Calibri", isTextBox: true,
    });
    footer(s, 2);
  }

  // ======================================================================
  // Slide 3 — Architecture
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    s.addText("Architecture", { x: 0.6, y: 0.35, w: 8, h: 0.6, fontSize: 30, bold: true, color: INK, fontFace: "Cambria", isTextBox: true });

    const boxLine = { color: "9AA7CE", width: 1 };
    const arrow = (x1, y1, x2, y2) => s.addShape("line", { x: x1, y: y1, w: x2 - x1, h: y2 - y1, line: { color: NAVY, width: 2, endArrowType: "triangle" } });

    // Internet
    iconCircle(s, "globe", W / 2 - 0.35, 1.15, 0.7, NAVY, 0.6);
    s.addText("Internet", { x: W / 2 - 1, y: 1.85, w: 2, h: 0.3, fontSize: 11, color: MUTED, align: "center", fontFace: "Calibri", isTextBox: true });
    arrow(W / 2, 1.85, W / 2, 2.25);

    // App Gateway
    s.addShape("roundRect", { x: W / 2 - 2.1, y: 2.25, w: 4.2, h: 0.85, fill: { color: NAVY }, line: { type: "none" }, rectRadius: 0.1 });
    iconCircle(s, "gateway", W / 2 - 1.9, 2.42, 0.5, NAVY_DARK, 0.6);
    s.addText("Application Gateway (WAF_v2)", { x: W / 2 - 1.25, y: 2.35, w: 3.3, h: 0.3, fontSize: 13, bold: true, color: WHITE, fontFace: "Calibri", isTextBox: true });
    s.addText("public IP · TLS termination · OWASP ruleset", { x: W / 2 - 1.25, y: 2.63, w: 3.3, h: 0.3, fontSize: 9.5, color: ICE, fontFace: "Calibri", isTextBox: true });
    arrow(W / 2, 3.1, W / 2, 3.5);
    s.addText("AGIC watches Ingress objects, reconfigures the Gateway automatically", {
      x: W / 2 + 0.15, y: 3.12, w: 3.6, h: 0.4, fontSize: 8.5, italic: true, color: MUTED, fontFace: "Calibri", isTextBox: true });

    // AKS cluster box
    const clY = 3.5, clH = 2.85;
    s.addShape("roundRect", { x: 1.4, y: clY, w: W - 2.8, h: clH, fill: { color: CARD_LIGHT }, line: { color: NAVY, width: 1.5, dashType: "dash" }, rectRadius: 0.1 });
    s.addText("AKS CLUSTER  —  PRIVATE API SERVER (no public control-plane IP)", {
      x: 1.6, y: clY + 0.12, w: W - 3.2, h: 0.35, fontSize: 12, bold: true, color: NAVY, fontFace: "Calibri", isTextBox: true, charSpacing: 0.5 });

    const poolW = 3.6, poolY = clY + 0.65, poolH = 1.9;
    // system pool
    s.addShape("roundRect", { x: 2.1, y: poolY, w: poolW, h: poolH, fill: { color: WHITE }, line: { color: "9AA7CE", width: 1 }, rectRadius: 0.08 });
    iconCircle(s, "server", 2.3, poolY + 0.2, 0.55, NAVY, 0.55);
    s.addText("System node pool", { x: 3.0, y: poolY + 0.22, w: 2.5, h: 0.3, fontSize: 12.5, bold: true, color: INK, fontFace: "Calibri", isTextBox: true });
    s.addText("mode=System · CriticalAddonsOnly taint\nAdd-ons only — no app workloads scheduled here", {
      x: 2.3, y: poolY + 0.85, w: poolW - 0.5, h: 0.9, fontSize: 10, color: MUTED, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.2 });

    // user pool
    const upX = 2.1 + poolW + 0.55;
    s.addShape("roundRect", { x: upX, y: poolY, w: poolW, h: poolH, fill: { color: WHITE }, line: { color: ACCENT, width: 1.5 }, rectRadius: 0.08 });
    iconCircle(s, "cubes", upX + 0.2, poolY + 0.2, 0.55, NAVY, 0.55);
    s.addText("User node pool (autoscaling)", { x: upX + 0.9, y: poolY + 0.22, w: 2.6, h: 0.3, fontSize: 12.5, bold: true, color: INK, fontFace: "Calibri", isTextBox: true });
    s.addText("namespace: demo-web · Deployment, 2-5\nreplicas via HorizontalPodAutoscaler", {
      x: upX + 0.2, y: poolY + 0.85, w: poolW - 0.5, h: 0.9, fontSize: 10, color: MUTED, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.2 });

    // downstream: ACR + Key Vault
    const downY = clY + clH + 0.35, boxW = 3.4, boxH = 1.05;
    const acrX = W / 2 - boxW - 0.4, kvX = W / 2 + 0.4;
    arrow(2.1 + poolW * 0.15, poolY + poolH, acrX + boxW / 2, downY);
    arrow(upX + poolW * 0.85, poolY + poolH, kvX + boxW / 2, downY);

    s.addShape("roundRect", { x: acrX, y: downY, w: boxW, h: boxH, fill: { color: NAVY }, line: { type: "none" }, rectRadius: 0.08 });
    iconCircle(s, "database", acrX + 0.18, downY + 0.22, 0.6, NAVY_DARK, 0.55);
    s.addText("Container Registry", { x: acrX + 0.95, y: downY + 0.14, w: boxW - 1.1, h: 0.3, fontSize: 12, bold: true, color: WHITE, fontFace: "Calibri", isTextBox: true });
    s.addText("Private endpoint · no admin user\nAcrPull via kubelet identity only", { x: acrX + 0.95, y: downY + 0.46, w: boxW - 1.1, h: 0.55, fontSize: 9, color: ICE, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.15 });

    s.addShape("roundRect", { x: kvX, y: downY, w: boxW, h: boxH, fill: { color: NAVY }, line: { type: "none" }, rectRadius: 0.08 });
    iconCircle(s, "key", kvX + 0.18, downY + 0.22, 0.6, NAVY_DARK, 0.55);
    s.addText("Key Vault", { x: kvX + 0.95, y: downY + 0.14, w: boxW - 1.1, h: 0.3, fontSize: 12, bold: true, color: WHITE, fontFace: "Calibri", isTextBox: true });
    s.addText("RBAC-authorized · private endpoint\nTLS cert synced via CSI driver identity", { x: kvX + 0.95, y: downY + 0.46, w: boxW - 1.1, h: 0.55, fontSize: 9, color: ICE, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.15 });

    footer(s, 3);
  }

  // ======================================================================
  // Slide 4 — Cluster breakdown
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    s.addText("Inside the Cluster", { x: 0.6, y: 0.4, w: 8, h: 0.6, fontSize: 30, bold: true, color: INK, fontFace: "Cambria", isTextBox: true });
    s.addText("Real Kubernetes objects, mapped to what they actually do here", {
      x: 0.6, y: 0.98, w: 10, h: 0.4, fontSize: 13, color: MUTED, fontFace: "Calibri", isTextBox: true });

    const rows = [
      ["namespace", "Namespace", "demo-web — isolates the app's objects, RBAC, and network policy"],
      ["sitemap", "Deployment", "2-5 replicas, non-root, read-only rootfs, all capabilities dropped"],
      ["network", "Service", "Stable ClusterIP — what the Ingress and Gateway actually target"],
      ["gateway", "Ingress + AGIC", "Declares routing intent; AGIC drives the real Application Gateway"],
      ["scale", "HorizontalPodAutoscaler", "Scales on CPU utilization (target 70%) with zero manual steps"],
      ["policy", "NetworkPolicy (×3)", "Default-deny; explicit allow only from the Gateway subnet + DNS"],
      ["cert", "SecretProviderClass", "Bridges the CSI driver to Key Vault — no cert material in Git"],
    ];
    const rowH = 0.63, startY = 1.55;
    rows.forEach(([ic, term, def], i) => {
      const y = startY + i * rowH;
      if (i % 2 === 1) s.addShape("rect", { x: 0.6, y, w: 12.1, h: rowH, fill: { color: CARD_LIGHT }, line: { type: "none" } });
      iconCircle(s, ic, 0.75, y + 0.07, 0.48, NAVY, 0.55);
      s.addText(term, { x: 1.45, y: y + 0.02, w: 3.1, h: rowH - 0.04, fontSize: 12.5, bold: true, color: INK, fontFace: "Calibri", isTextBox: true, valign: "middle" });
      s.addText(def, { x: 4.65, y: y + 0.02, w: 8, h: rowH - 0.04, fontSize: 11.5, color: MUTED, fontFace: "Calibri", isTextBox: true, valign: "middle" });
    });
    footer(s, 4);
  }

  // ======================================================================
  // Slide 5 — Security & design principles
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: NAVY };
    s.addText("Security by Design", { x: 0.6, y: 0.5, w: 10, h: 0.7, fontSize: 30, bold: true, color: WHITE, fontFace: "Cambria", isTextBox: true });

    const items = [
      ["lock", "Private API server", "No public control-plane IP, anywhere"],
      ["branch", "OIDC-only CI/CD", "Federated tokens — zero stored Azure secrets in GitHub"],
      ["userShield", "Azure RBAC + Entra ID", "Cluster access is group membership, not a static kubeconfig"],
      ["policy", "Default-deny NetworkPolicy", "Explicit allow only from the Gateway; egress limited to DNS"],
      ["shield", "Non-root everywhere", "Read-only rootfs, dropped capabilities, seccomp RuntimeDefault"],
      ["key", "No embedded credentials", "ACR, Key Vault, and Gateway access all via managed identity"],
    ];
    const cols = 3, cardW = 3.85, cardH = 2.15, gapX = 0.28, gapY = 0.3;
    const startX = (W - (cardW * cols + gapX * (cols - 1))) / 2, startY = 1.65;
    items.forEach(([ic, title, desc], i) => {
      const col = i % cols, row = Math.floor(i / cols);
      const x = startX + col * (cardW + gapX), y = startY + row * (cardH + gapY);
      s.addShape("roundRect", { x, y, w: cardW, h: cardH, fill: { color: NAVY_DARK }, line: { type: "none" }, rectRadius: 0.1 });
      iconCircle(s, ic, x + 0.25, y + 0.25, 0.65, "27306E", 0.55);
      s.addText(title, { x: x + 0.25, y: y + 1.0, w: cardW - 0.5, h: 0.55, fontSize: 14, bold: true, color: WHITE, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.05 });
      s.addText(desc, { x: x + 0.25, y: y + 1.5, w: cardW - 0.5, h: 0.6, fontSize: 10.5, color: ICE, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.15 });
    });
    footer(s, 5, true);
  }

  // ======================================================================
  // Slide 6 — CI/CD pipeline
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    s.addText("From git push to a running pod", { x: 0.6, y: 0.4, w: 11, h: 0.6, fontSize: 28, bold: true, color: INK, fontFace: "Cambria", isTextBox: true });

    const steps = [
      ["branch", "Push", "What-If runs on\nevery PR, shows\nthe exact diff"],
      ["sync", "Build & Push", "OIDC login, image\nbuilt, tagged with\ngit SHA, pushed to ACR"],
      ["cubes", "Bicep Deploy", "Dev auto-deploys;\nprod behind an\napproval gate"],
      ["server", "kubectl apply", "Via az aks command\ninvoke — the only path\ninto a private API server"],
      ["gateway", "AGIC reconciles", "Gateway listener +\nbackend pool updated\nto match the Ingress"],
    ];
    const n = steps.length, cw = 2.15, gap = (12.1 - cw * n) / (n - 1), y = 2.2;
    steps.forEach(([ic, title, desc], i) => {
      const x = 0.6 + i * (cw + gap);
      iconCircle(s, ic, x + cw / 2 - 0.45, y, 0.9, NAVY, 0.55);
      s.addText(String(i + 1), { x: x + cw / 2 + 0.15, y: y - 0.08, w: 0.4, h: 0.4, fontSize: 13, bold: true, color: NAVY,
        fill: { color: ACCENT }, align: "center", valign: "middle", fontFace: "Calibri", isTextBox: true, rectRadius: 0.2 });
      s.addText(title, { x, y: y + 1.05, w: cw, h: 0.4, fontSize: 13, bold: true, color: INK, align: "center", fontFace: "Calibri", isTextBox: true });
      s.addText(desc, { x, y: y + 1.45, w: cw, h: 1.1, fontSize: 9.5, color: MUTED, align: "center", fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.15 });
      if (i < n - 1) {
        s.addShape("line", { x: x + cw + 0.06, y: y + 0.45, w: gap - 0.12, h: 0, line: { color: "9AA7CE", width: 2, endArrowType: "triangle" } });
      }
    });

    s.addShape("roundRect", { x: 0.6, y: 5.1, w: 12.1, h: 1.15, fill: { color: CARD_LIGHT }, line: { type: "none" }, rectRadius: 0.1 });
    s.addText("Why this matters: a GitHub-hosted runner has no network line-of-sight into the cluster at all. " +
      "“command invoke” executes kubectl inside the cluster's own control plane — zero VPN, self-hosted runner, or Bastion host required.", {
      x: 0.95, y: 5.28, w: 11.4, h: 0.8, fontSize: 12, italic: true, color: NAVY, fontFace: "Calibri", isTextBox: true, valign: "middle", lineSpacingMultiple: 1.25 });
    footer(s, 6);
  }

  // ======================================================================
  // Slide 7 — Real incident case study
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: NAVY };
    iconCircle(s, "warnWhite", 0.6, 0.5, 0.7, NAVY_DARK, 0.6);
    s.addText("A Real Incident, Not a Demo", { x: 1.5, y: 0.5, w: 10, h: 0.6, fontSize: 28, bold: true, color: WHITE, fontFace: "Cambria", isTextBox: true });
    s.addText("Prod's app sat in ContainerCreating for 24+ hours, undetected — diagnosed and fixed live, five layers deep.", {
      x: 1.5, y: 1.05, w: 11, h: 0.4, fontSize: 13, color: ICE, fontFace: "Calibri", isTextBox: true });

    const layers = [
      ["Invalid vault name: “REPLACE_WITH_KEY_VAULT_NAME”", "Prod's overlay was missing a patch dev already had"],
      ["ForbiddenByRbac", "Admin identity lacked Key Vault Certificates Officer on that vault"],
      ["ForbiddenByConnection", "Vault is private by design — no VPN/Bastion path in, even for an authorized identity"],
      ["SecretNotFound (404)", "The TLS certificate simply didn't exist in prod's vault yet"],
      ["InvalidImageName", "A manual kustomize apply bypassed CI's image-substitution step mid-recovery"],
    ];
    const rowH = 0.83, startY = 1.75;
    layers.forEach(([err, why], i) => {
      const y = startY + i * rowH;
      s.addShape("roundRect", { x: 0.6, y, w: 0.5, h: 0.5, fill: { color: ACCENT }, line: { type: "none" }, rectRadius: 0.25 });
      s.addText(String(i + 1), { x: 0.6, y, w: 0.5, h: 0.5, fontSize: 14, bold: true, color: NAVY, align: "center", valign: "middle", fontFace: "Calibri", isTextBox: true });
      s.addText(err, { x: 1.3, y: y - 0.02, w: 5.3, h: 0.4, fontSize: 12.5, bold: true, color: ACCENT, fontFace: "Courier New", isTextBox: true });
      s.addText(why, { x: 6.75, y: y - 0.02, w: 6.0, h: 0.6, fontSize: 11, color: ICE, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.15 });
    });

    s.addText("Full root-cause timeline: docs/webplat-architecture.md → “Incident: prod SecretProviderClass never patched”", {
      x: 0.6, y: startY + layers.length * rowH + 0.15, w: 12, h: 0.4, fontSize: 10.5, italic: true, color: "8891C0", fontFace: "Calibri", isTextBox: true });
    footer(s, 7, true);
  }

  // ======================================================================
  // Slide 8 — Glossary
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    s.addText("Kubernetes, Explained", { x: 0.6, y: 0.4, w: 10, h: 0.6, fontSize: 30, bold: true, color: INK, fontFace: "Cambria", isTextBox: true });
    s.addText("Key terms, in plain language, in the context of this project", {
      x: 0.6, y: 0.98, w: 10, h: 0.4, fontSize: 13, color: MUTED, fontFace: "Calibri", isTextBox: true });

    const terms = [
      ["Pod", "The smallest deployable unit — one or more containers sharing network/storage"],
      ["Node", "A VM that runs pods — here, an Azure VM Scale Set instance"],
      ["Deployment", "Declares “I want N copies running” and reconciles reality toward that"],
      ["ReplicaSet", "The Deployment's mechanism — a new one on every pod-template change"],
      ["Service", "A stable network identity for pods, even as pod IPs come and go"],
      ["Ingress", "A declarative routing rule; needs a controller (AGIC) to act on it"],
      ["HPA", "Horizontal Pod Autoscaler — changes replica count based on live metrics"],
      ["CSI driver", "A plugin standard for mounting external storage/secrets into pods"],
      ["Managed Identity", "An Azure AD identity Azure manages the credential for — no key to leak"],
      ["Private cluster", "The Kubernetes API server has no public IP at all"],
    ];
    const cols = 2, colW = 5.85, rowH = 0.86, startY = 1.65, gapX = 0.4;
    terms.forEach(([term, def], i) => {
      const col = i % cols, row = Math.floor(i / cols);
      const x = 0.6 + col * (colW + gapX), y = startY + row * rowH;
      s.addText(term, { x, y, w: colW, h: 0.32, fontSize: 13, bold: true, color: NAVY, fontFace: "Calibri", isTextBox: true });
      s.addText(def, { x, y: y + 0.32, w: colW, h: 0.5, fontSize: 10.5, color: MUTED, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.1 });
    });
    footer(s, 8);
  }

  // ======================================================================
  // Slide 9 — Use cases
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    s.addText("Where This Pattern Fits", { x: 0.6, y: 0.4, w: 10, h: 0.6, fontSize: 30, bold: true, color: INK, fontFace: "Cambria", isTextBox: true });

    const cases = [
      ["building", "Company websites with an SLA", "Where “the site is down” is a business incident, not an inconvenience"],
      ["lock", "Private line-of-business apps", "Need network isolation but still a public-facing front door"],
      ["shield", "Client engagement reference", "Every piece answers a security-conscious procurement checklist"],
      ["sitemap", "Multi-environment platforms", "Each environment isolated at the network level, not just namespaced"],
    ];
    const cardW = 5.85, cardH = 2.3, gapX = 0.4, gapY = 0.35, startX = 0.6, startY = 1.5;
    cases.forEach(([ic, title, desc], i) => {
      const col = i % 2, row = Math.floor(i / 2);
      const x = startX + col * (cardW + gapX), y = startY + row * (cardH + gapY);
      s.addShape("roundRect", { x, y, w: cardW, h: cardH, fill: { color: CARD_LIGHT }, line: { type: "none" }, rectRadius: 0.1,
        shadow: { type: "outer", color: "1E2761", opacity: 0.1, blur: 5, offset: 2, angle: 90 } });
      iconCircle(s, ic, x + 0.3, y + 0.3, 0.7, NAVY, 0.55);
      s.addText(title, { x: x + 1.2, y: y + 0.3, w: cardW - 1.5, h: 0.7, fontSize: 15, bold: true, color: INK, fontFace: "Calibri", isTextBox: true, valign: "top", lineSpacingMultiple: 1.1 });
      s.addText(desc, { x: x + 0.3, y: y + 1.25, w: cardW - 0.6, h: 0.9, fontSize: 11, color: MUTED, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.2 });
    });
    footer(s, 9);
  }

  // ======================================================================
  // Slide 10 — Evidence
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: NAVY };
    iconCircle(s, "checkWhite", 0.6, 0.5, 0.7, NAVY_DARK, 0.6);
    s.addText("Proof, Not Just Claims", { x: 1.5, y: 0.5, w: 10, h: 0.6, fontSize: 28, bold: true, color: WHITE, fontFace: "Cambria", isTextBox: true });
    s.addText("Real command output, captured live from both environments", {
      x: 1.5, y: 1.05, w: 10, h: 0.4, fontSize: 13, color: ICE, fontFace: "Calibri", isTextBox: true });

    const term = (x, y, w, h, title, lines) => {
      s.addShape("roundRect", { x, y, w, h, fill: { color: "0E1235" }, line: { color: "2A3470", width: 1 }, rectRadius: 0.08 });
      s.addShape("ellipse", { x: x + 0.18, y: y + 0.16, w: 0.12, h: 0.12, fill: { color: "E4572E" }, line: { type: "none" } });
      s.addShape("ellipse", { x: x + 0.38, y: y + 0.16, w: 0.12, h: 0.12, fill: { color: "E8B71A" }, line: { type: "none" } });
      s.addShape("ellipse", { x: x + 0.58, y: y + 0.16, w: 0.12, h: 0.12, fill: { color: "3DBE5C" }, line: { type: "none" } });
      s.addText(title, { x: x + 0.8, y: y + 0.07, w: w - 1, h: 0.3, fontSize: 9.5, color: "8891C0", fontFace: "Calibri", isTextBox: true });
      s.addText(lines, { x: x + 0.25, y: y + 0.45, w: w - 0.5, h: h - 0.6, fontSize: 10, color: ACCENT, fontFace: "Courier New", isTextBox: true, lineSpacingMultiple: 1.25 });
    };

    term(0.6, 1.65, 3.9, 2.1, "curl — prod", "HTTP/1.1 200 OK\nServer: nginx/1.27.5\n\n$ curl .../healthz\nok");
    term(4.75, 1.65, 3.9, 2.1, "kubectl get pods — prod", "demo-web-ccc969478-8cmfs\n  1/1  Running\ndemo-web-ccc969478-lmgm2\n  1/1  Running");
    term(8.9, 1.65, 3.83, 2.1, "App Gateway backend health", "10.31.0.103   Healthy\n10.31.0.136   Healthy\n\n(both environments)");

    s.addShape("roundRect", { x: 0.6, y: 4.05, w: 12.13, h: 1.75, fill: { color: NAVY_DARK }, line: { type: "none" }, rectRadius: 0.1 });
    s.addText("12 pieces of evidence in the repo", { x: 0.95, y: 4.25, w: 8, h: 0.4, fontSize: 13, bold: true, color: WHITE, fontFace: "Calibri", isTextBox: true });
    s.addText(
      "Resource groups · node pool health · private DNS zone · kubectl get nodes · pods running · backend health · " +
      "end-to-end curl · cluster overview · Defender inventory — across both dev and prod, screenshots and raw command output alike.",
      { x: 0.95, y: 4.65, w: 11.4, h: 1.0, fontSize: 11, color: ICE, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.3 }
    );
    footer(s, 10, true);
  }

  // ======================================================================
  // Slide 11 — Closing
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: NAVY };
    iconCircle(s, "cloud", W / 2 - 0.5, 0.7, 1.0, NAVY_DARK, 0.55);
    s.addText("Let's Talk", { x: 0.8, y: 2.0, w: W - 1.6, h: 0.8, fontSize: 36, bold: true, color: WHITE, align: "center", fontFace: "Cambria", isTextBox: true });

    const skills = [
      "Private AKS + Azure networking design",
      "Zero-secret CI/CD with OIDC federation",
      "Live production incident diagnosis",
      "Infrastructure as Code (Bicep) at scale",
    ];
    s.addText(skills.map((t, i) => ({ text: t, options: { bullet: { code: "2713" }, color: ICE, breakLine: i < skills.length - 1, fontSize: 14 } })), {
      x: W / 2 - 3.6, y: 3.05, w: 7.2, h: 1.9, fontFace: "Calibri", isTextBox: true, align: "left", paraSpaceAfter: 10,
    });

    s.addShape("line", { x: W / 2 - 2, y: 5.15, w: 4, h: 0, line: { color: "3B4590", width: 1 } });
    s.addText("Sufyan Deen-Gabisi", { x: 0.8, y: 5.35, w: W - 1.6, h: 0.4, fontSize: 15, bold: true, color: WHITE, align: "center", fontFace: "Calibri", isTextBox: true });
    s.addText("github.com/sufideen/az-ent-sec-dashboard", { x: 0.8, y: 5.75, w: W - 1.6, h: 0.35, fontSize: 12, color: ACCENT, align: "center", fontFace: "Calibri", isTextBox: true });
    s.addText("Full technical write-up, evidence, and runbook in the repository's docs/ folder", {
      x: 0.8, y: 6.15, w: W - 1.6, h: 0.35, fontSize: 10.5, color: "8891C0", align: "center", fontFace: "Calibri", isTextBox: true });
  }

  const path = require("path");
  const outPath = path.join(__dirname, "..", "..", "docs", "webplat-kubernetes-showcase.pptx");
  await pres.writeFile({ fileName: outPath });
  console.log("Wrote", outPath);
}

main().catch((e) => { console.error(e); process.exit(1); });
