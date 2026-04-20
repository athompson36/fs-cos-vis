/**
 * Minimal HTTPS-capable feedback relay for FSDMXVision.
 *
 * Env:
 *   RELAY_SECRET   — required; must match Settings → Relay authorization (Bearer token)
 *   GITHUB_TOKEN   — fine-grained or classic PAT with Issues: write on the target repo
 *   PORT           — default 8080
 *
 * FSDMXVision POST body: { title, body, repository, appVersion }
 * Set Feedback relay URL to e.g. http://127.0.0.1:8080/ (local) or https://your-host/ (prod).
 */
import express from "express";

const app = express();
app.use(express.json({ limit: "512kb" }));

const RELAY_SECRET = process.env.RELAY_SECRET;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const PORT = Number(process.env.PORT) || 8080;

app.post("/", async (req, res) => {
  if (!RELAY_SECRET) {
    console.error("RELAY_SECRET is not set");
    return res.status(500).json({ error: "relay_misconfigured" });
  }
  if (!GITHUB_TOKEN) {
    console.error("GITHUB_TOKEN is not set");
    return res.status(500).json({ error: "relay_misconfigured" });
  }

  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (token !== RELAY_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const { title, body, repository, appVersion } = req.body || {};
  if (typeof title !== "string" || !title.trim()) {
    return res.status(400).json({ error: "title required" });
  }
  if (typeof body !== "string") {
    return res.status(400).json({ error: "body required" });
  }
  if (typeof repository !== "string" || !repository.includes("/")) {
    return res.status(400).json({ error: "repository must be owner/name" });
  }

  const issueBody =
    (typeof appVersion === "string" && appVersion
      ? `**App:** ${appVersion}\n\n`
      : "") + body;

  const ghRes = await fetch(`https://api.github.com/repos/${repository}/issues`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: JSON.stringify({
      title: title.trim(),
      body: issueBody,
      labels: ["feedback"],
    }),
  });

  if (!ghRes.ok) {
    const text = await ghRes.text();
    console.error("GitHub API error", ghRes.status, text);
    return res.status(502).json({ error: "github_error", status: ghRes.status });
  }

  res.status(201).json({ ok: true });
});

app.listen(PORT, () => {
  console.log(`cosmic-feedback-relay listening on port ${PORT}`);
});
