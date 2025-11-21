const fs = require("fs");

const input = (name, defaultValue = "") => {
  const raw = process.env[`INPUT_${name.replace(/ /g, "_").toUpperCase()}`];
  return (raw || "").trim() || defaultValue;
};

const writeOutput = (name, value) => {
  const file = process.env.GITHUB_OUTPUT;
  if (!file) return;
  fs.appendFileSync(file, `${name}=${value}\n`, { encoding: "utf8" });
};

const allowedTypes = new Set(
  input("allowed-types")
    .split(",")
    .map((t) => t.trim().toLowerCase())
    .filter(Boolean)
);

const requireScope = input("require-scope").toLowerCase() === "true";
const allowDraft = input("allow-draft").toLowerCase() === "true";

const eventPath = process.env.GITHUB_EVENT_PATH;
if (!eventPath || !fs.existsSync(eventPath)) {
  console.error("::error::GITHUB_EVENT_PATH missing; cannot read PR payload");
  process.exit(1);
}

const payload = JSON.parse(fs.readFileSync(eventPath, "utf8"));
const pr = payload.pull_request;

if (!pr) {
  console.error("::error::This action only runs on pull_request events");
  process.exit(1);
}

if (!allowDraft && pr.draft) {
  console.error("::error::Draft pull requests are not allowed");
  process.exit(1);
}

const title = (pr.title || "").trim();

const match = title.match(/^([a-z]+)(\([^)]+\))?:\s.+/);
if (!match) {
  console.error(
    "::error::Title must follow Conventional Commit format: type(scope?): subject"
  );
  process.exit(1);
}

const [, type, scope] = match;

if (!allowedTypes.has(type)) {
  console.error(
    `::error::Type "${type}" is not allowed. Allowed: ${Array.from(
      allowedTypes
    ).join(", ")}`
  );
  process.exit(1);
}

if (requireScope && !scope) {
  console.error("::error::Scope is required: type(scope): subject");
  process.exit(1);
}

writeOutput("normalized-title", title);
console.log(`Title accepted: ${title}`);
