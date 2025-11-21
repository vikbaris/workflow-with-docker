// Simple lint placeholder: fails if source file contains TODO markers.
const fs = require("fs");
const path = require("path");

const file = path.join(__dirname, "..", "src", "index.js");
const content = fs.readFileSync(file, "utf8");

if (content.includes("TODO")) {
  console.error("Lint failed: TODO found in src/index.js");
  process.exit(1);
}

console.log("Lint passed");
