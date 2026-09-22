const pptxgen = require("pptxgenjs");
const path = require("path");
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
    s.addText("How I designed, deployed, broke, diagnosed and fixed\na private AKS platform on real Azure infrastructure", {
      x: 1.3, y: 3.35, w: W - 2.6, h: 0.9, fontSize: 17, color: ICE,
      align: "center", fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.25,
    });
    s.addShape("rect", { x: W / 2 - 1.9, y: 4.55, w: 3.8, h: 0.55, fill: { color: NAVY_DARK }, line: { color: ACCENT, width: 1 }, rectRadius: 0.28 });
    s.addText("LIVE DEMO  ·  DEV ENVIRONMENT", {
      x: W / 2 - 1.9, y: 4.55, w: 3.8, h: 0.55, fontSize: 11, bold: true, color: ACCENT,
      align: "center", valign: "middle", fontFace: "Calibri", isTextBox: true, charSpacing: 1,
    });
    s.addText("Presented by Sufyan Deen-Gabisi   ·   github.com/sufideen/az-ent-sec-dashboard", {
      x: 0.8, y: H - 0.75, w: W - 1.6, h: 0.4, fontSize: 11, color: "8891C0",
      align: "center", fontFace: "Calibri", isTextBox: true,
    });
    s.addNotes("Thanks for having me. Over the next five minutes I'll show you a platform I designed and built myself: a private Kubernetes cluster on Azure, deployed through a pipeline with no stored passwords. I'll show it running live, and I'll also show you what broke when I rebuilt it from scratch tonight, because that's where the real depth is.");
  }

  // ======================================================================
  // Slide 2 — Executive Summary (transitions into the live demo)
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    s.addText("What I Built", { x: 0.6, y: 0.45, w: 8, h: 0.7, fontSize: 32, bold: true, color: INK, fontFace: "Cambria", isTextBox: true });
    s.addText(
      "I built a containerized web application on a private Azure Kubernetes Service cluster. It sits behind a " +
      "WAF-enabled Application Gateway with a Let's Encrypt-issued TLS certificate, pulls images from a private " +
      "container registry, and is deployed by GitHub Actions using OIDC, so there are no long-lived credentials " +
      "anywhere in the pipeline.",
      { x: 0.6, y: 1.25, w: 12.1, h: 0.9, fontSize: 14.5, color: MUTED, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.25 }
    );

    const stats = [
      ["lock", "0", "Stored credentials\nin the pipeline"],
      ["server", "PRIVATE", "API server —\nno public IP"],
      ["cert", "LET'S ENCRYPT", "Real, trusted TLS —\nauto-renewed"],
      ["warn", "5", "Real incidents,\nfixed live tonight"],
    ];
    const cardW = 2.85, gap = 0.28, startX = (W - (cardW * 4 + gap * 3)) / 2, cardY = 2.55, cardH = 2.55;
    stats.forEach(([ic, big, label], i) => {
      const x = startX + i * (cardW + gap);
      s.addShape("roundRect", { x, y: cardY, w: cardW, h: cardH, fill: { color: CARD_LIGHT }, line: { type: "none" }, rectRadius: 0.12,
        shadow: { type: "outer", color: "1E2761", opacity: 0.12, blur: 6, offset: 3, angle: 90 } });
      iconCircle(s, ic, x + cardW / 2 - 0.4, cardY + 0.35, 0.8, NAVY);
      s.addText(big, { x: x + 0.1, y: cardY + 1.3, w: cardW - 0.2, h: 0.55, fontSize: 19, bold: true, color: NAVY, align: "center", fontFace: "Cambria", isTextBox: true });
      s.addText(label, { x: x + 0.15, y: cardY + 1.85, w: cardW - 0.3, h: 0.6, fontSize: 11.5, color: MUTED, align: "center", fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.1 });
    });

    s.addText("Rebuilt from scratch and re-verified end to end tonight: real pods, real Let's Encrypt TLS, a real public IP and a real HTTP 200.", {
      x: 0.6, y: 5.55, w: 12.1, h: 0.5, fontSize: 12.5, italic: true, color: NAVY, fontFace: "Calibri", isTextBox: true,
    });
    s.addNotes("In one sentence: it's a website running on Kubernetes that I locked down properly. The API server has no public address, TLS is a real Let's Encrypt certificate, and nothing in the pipeline holds a password or key. Let's go look at it live — [switch to browser: dev-webplat.ict-cloud.solutions, click through Architecture and Configuration, then a terminal check of pods/certs].");
    footer(s, 2);
  }

  // ======================================================================
  // Slide 3 — How It Actually Works (plain-English connectivity diagram)
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: WHITE };
    const imgPath = path.join(__dirname, "assets", "plain-english-connectivity.png");
    // Image is 1200x675 (16:9) — same aspect as the slide, so it drops in edge-to-edge.
    s.addImage({ path: imgPath, x: 0.75, y: 0.35, w: 11.65, h: 6.56 });
    s.addNotes("For anyone in the room who isn't deep into Kubernetes, here's the same design in plain language. A visitor's traffic travels over a locked connection, past a guarded front door that blocks attacks, into a vault with no public entrance. Separately, updates are delivered using a temporary digital ID that expires in minutes — never a stored password. Same system as the last slide, just described for a general audience.");
    footer(s, 3);
  }

  // ======================================================================
  // Slide 4 — Real incident: tonight's full rebuild
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: NAVY };
    iconCircle(s, "warnWhite", 0.6, 0.5, 0.7, NAVY_DARK, 0.6);
    s.addText("Torn Down, Rebuilt, Verified — Live", { x: 1.5, y: 0.5, w: 11, h: 0.6, fontSize: 26, bold: true, color: WHITE, fontFace: "Cambria", isTextBox: true });
    s.addText("Tonight I deleted this environment and rebuilt it from scratch. Here's what broke, five layers deep.", {
      x: 1.5, y: 1.05, w: 11, h: 0.4, fontSize: 13, color: ICE, fontFace: "Calibri", isTextBox: true });

    const layers = [
      ["OIDC login rejected", "GitHub's federated credential was scoped to a branch that no longer existed"],
      ["RBAC silently gone", "Role assignments are scoped to the resource — deleting it deletes the access, ARM and Kubernetes RBAC both"],
      ["Key Vault soft-deleted, not gone", "Purge protection blocked recreating it under the same name until I recovered it"],
      ["Stale managed identity", "The Key Vault CSI add-on gets a new identity every rebuild — the old client ID in my manifest broke cert delivery"],
      ["DNS + Gateway both stale", "A new public IP meant updating DNS, then waiting on the Gateway's own data-plane propagation"],
    ];
    const rowH = 0.83, startY = 1.75;
    layers.forEach(([err, why], i) => {
      const y = startY + i * rowH;
      s.addShape("roundRect", { x: 0.6, y, w: 0.5, h: 0.5, fill: { color: ACCENT }, line: { type: "none" }, rectRadius: 0.25 });
      s.addText(String(i + 1), { x: 0.6, y, w: 0.5, h: 0.5, fontSize: 14, bold: true, color: NAVY, align: "center", valign: "middle", fontFace: "Calibri", isTextBox: true });
      s.addText(err, { x: 1.3, y: y - 0.02, w: 4.7, h: 0.5, fontSize: 12.5, bold: true, color: ACCENT, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.1 });
      s.addText(why, { x: 6.15, y: y - 0.02, w: 6.6, h: 0.65, fontSize: 11, color: ICE, fontFace: "Calibri", isTextBox: true, lineSpacingMultiple: 1.15 });
    });

    s.addText("Full root-cause timeline: docs/webplat-architecture.md → “Incident: prod SecretProviderClass never patched” and the teardown/rebuild runbook", {
      x: 0.6, y: startY + layers.length * rowH + 0.15, w: 12, h: 0.4, fontSize: 10.5, italic: true, color: "8891C0", fontFace: "Calibri", isTextBox: true });
    s.addNotes("This is the slide I'm most glad to show. None of this is hypothetical — I tore this environment down myself a few hours ago and rebuilt it live, and each of these five things broke in turn, each one hiding the next. What I took from it: resource-group deletion doesn't just delete resources, it silently deletes every RBAC grant and cached identity pointing at them, and that's worth writing into the runbook.");
    footer(s, 4, true);
  }

  // ======================================================================
  // Slide 5 — Closing
  // ======================================================================
  {
    const s = pres.addSlide();
    s.background = { color: NAVY };
    iconCircle(s, "cloud", W / 2 - 0.5, 0.7, 1.0, NAVY_DARK, 0.55);
    s.addText("Let's Talk", { x: 0.8, y: 2.0, w: W - 1.6, h: 0.8, fontSize: 36, bold: true, color: WHITE, align: "center", fontFace: "Cambria", isTextBox: true });

    const skills = [
      "Private AKS + Azure networking design",
      "Zero-secret CI/CD with OIDC federation",
      "Full environment teardown-and-rebuild, diagnosed live",
      "Let's Encrypt TLS via cert-manager, zero manual certs",
    ];
    s.addText(skills.map((t, i) => ({ text: t, options: { bullet: { code: "2713" }, color: ICE, breakLine: i < skills.length - 1, fontSize: 14 } })), {
      x: W / 2 - 3.6, y: 3.05, w: 7.2, h: 1.9, fontFace: "Calibri", isTextBox: true, align: "left", paraSpaceAfter: 10,
    });

    s.addShape("line", { x: W / 2 - 2, y: 5.15, w: 4, h: 0, line: { color: "3B4590", width: 1 } });
    s.addText("Sufyan Deen-Gabisi", { x: 0.8, y: 5.35, w: W - 1.6, h: 0.4, fontSize: 15, bold: true, color: WHITE, align: "center", fontFace: "Calibri", isTextBox: true });
    s.addText("github.com/sufideen/az-ent-sec-dashboard", { x: 0.8, y: 5.75, w: W - 1.6, h: 0.35, fontSize: 12, color: ACCENT, align: "center", fontFace: "Calibri", isTextBox: true });
    s.addText("The full write-up, evidence and runbook are in the docs/ folder of the repository", {
      x: 0.8, y: 6.15, w: W - 1.6, h: 0.35, fontSize: 10.5, color: "8891C0", align: "center", fontFace: "Calibri", isTextBox: true });
    s.addNotes("To sum up: I can design a private, zero-secret Kubernetes platform on Azure, automate its delivery, and when a full environment teardown breaks five things at once, work through it methodically and get it back to a trusted, verified state. Happy to take questions, or go deeper on any part of this live.");
  }

  const outPath = path.join(__dirname, "..", "..", "docs", "webplat-kubernetes-showcase.pptx");
  await pres.writeFile({ fileName: outPath });
  console.log("Wrote", outPath);
}

main().catch((e) => { console.error(e); process.exit(1); });
