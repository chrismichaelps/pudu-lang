// Every diagnostic code means one thing.
//
// `E1049` once meant both "a statement ends at the line break" and "a macro
// argument is the wrong kind". A reader who looked it up was told about a
// missing line break or about a macro depending on which answer they found
// first, and nothing in the build noticed.
//
// A code reported from two modules is the signal, because two modules is how
// two meanings get in. Some codes are legitimately shared — a generic
// "expected a token" belongs to whatever is parsing — so each one is listed
// here with why. Adding a code to this list is a claim that both sites mean
// the same thing to a reader.
//
// Usage: node test/diagnostic-codes.mjs [src-directory]

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";

const root = process.argv[2] ?? "src";

const shared = new Map([
  ["E1001", "the generic wrong-token report, raised wherever a parser expects something"],
  ["E1032", "a function body is missing, from a declaration and from a literal"],
  ["E1044", "an unknown unsafe capability, from a declaration and from an expression"],
  ["E2010", "an unresolved value name, from resolution and from its context"],
  ["E3010", "a name others can see must state its type: a binding where declarations are checked, a function or parameter where signatures are"],
  ["E3001", "the type mismatch, raised wherever two types are required to agree"],
  ["E3003", "a call's argument count disagreeing with the declaration: too many, which the type alone shows, and too few, which only the declaration's defaults can decide"],
  ["E3005", "a member the receiver does not have, from field access and from method lookup"],
  ["E3013", "an ambiguous method, from trait dispatch and from coherence"],
  ["E3028", "type arguments written where they cannot be carried"],
  ["E3030", "a type that cannot stand where it was written, from formation and from iteration"],
  ["E3034", "a named variant used as a value, from a bare name and from a callee"],
  ["E7001", "a value of the wrong shape at run time, raised across the evaluator"],
  ["E7002", "an evaluation limit, from the loop forms and from call depth"],
  ["E7003", "a call's arity, from the evaluator and from its builtins"],
  ["E7004", "an operand outside the range its operation allows"],
  ["E7008", "await used where it cannot be, from the evaluator and from its builtins"],
  ["E7009", "an effect refused while a constant is folded, from the effects and from starting a thread"],
  ["E7012", "a built-in given arguments it does not accept, from the builtins and the effects"],
]);

const sources = [];
const walk = directory => {
  for (const entry of readdirSync(directory)) {
    const path = join(directory, entry);
    if (statSync(path).isDirectory()) walk(path);
    else if (path.endsWith(".hs")) sources.push(path);
  }
};
walk(root);

const sites = new Map();
for (const path of sources) {
  const text = readFileSync(path, "utf8");
  for (const match of text.matchAll(/"([EW]\d{4})"/g)) {
    const code = match[1];
    if (!sites.has(code)) sites.set(code, new Set());
    sites.get(code).add(path);
  }
}

const failures = [];
for (const [code, files] of [...sites].sort()) {
  if (files.size <= 1) continue;
  if (shared.has(code)) continue;
  failures.push(`${code} is reported from ${files.size} modules:\n    ${[...files].sort().join("\n    ")}`);
}

// A code that stopped being shared should stop being excused.
const stale = [...shared.keys()].filter(code => (sites.get(code)?.size ?? 0) <= 1);
for (const code of stale) {
  failures.push(`${code} is listed as shared but is reported from one module; drop it from the list`);
}

if (failures.length > 0) {
  console.error("diagnostic-codes: a code must mean one thing.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  console.error("  If both sites really mean the same thing, add the code to `shared` with why.");
  process.exit(1);
}

console.log(JSON.stringify({ codes: sites.size, shared: shared.size, sources: sources.length }));
