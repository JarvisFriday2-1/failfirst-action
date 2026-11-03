#!/usr/bin/env bash
# Build a throwaway repo for the self-test. Usage: fixture.sh honest|hollow <dir>
# main: add() with a test. Branch fix: adds mul() with a test (honest) or a test that
# passes without exercising it (hollow). Leaves the repo checked out on fix.
set -eu
MODE="$1" DIR="$2"
G="git -c user.name=fixture -c user.email=fixture@example.com"
rm -rf "$DIR" && mkdir -p "$DIR/src" "$DIR/test" && cd "$DIR"
$G init -q -b main .
cat > package.json <<'JSON'
{ "name": "fixture", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test \"test/**/*.test.js\"" } }
JSON
printf 'export const add = (a, b) => a + b;\n' > src/math.js
printf 'import test from "node:test"; import assert from "node:assert";\nimport { add } from "../src/math.js";\ntest("add", () => assert.equal(add(2, 3), 5));\n' > test/math.test.js
printf 'node_modules/\n.failfirst/\n' > .gitignore
$G add -A && $G commit -qm base
$G checkout -qb fix
case "$MODE" in
  honest)
    printf 'export const add = (a, b) => a + b;\nexport const mul = (a, b) => a * b;\n' > src/math.js
    printf 'import test from "node:test"; import assert from "node:assert";\nimport { mul } from "../src/math.js";\ntest("mul", () => assert.equal(mul(2, 3), 6));\n' > test/mul.test.js ;;
  hollow)
    printf 'export const add = (a, b) => a + b;\nexport const mul = (a, b) => a * b;\n' > src/math.js
    printf 'import test from "node:test";\ntest("mul", () => {});\n' > test/mul.test.js ;;
  *) echo "fixture.sh: mode must be honest or hollow" >&2; exit 2 ;;
esac
$G add -A && $G commit -qm "$MODE fix"
