// Minimal test placeholder: checks exported greet() output.
const assert = require("assert");
const { greet } = require("../src/index");

const expected = "Hello from demo-api";
assert.strictEqual(greet(), expected, "greet() should return the expected string");

console.log("Tests passed");
