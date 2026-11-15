import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// A cold hosted simulator can take minutes to install or launch its first app.
const simulatorTimeout = 300_000;
const launchAttempts = 2;

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..");
// The counter imports Std.Mobile from this checkout, whichever compiler runs.
process.env.PUDU_LIB ??= join(repository, "packages", "pudu", "v0.1", "lib");

function run(command, args, timeout = 120_000, env = process.env) {
  const result = spawnSync(command, args, { encoding: "utf8", timeout, env });
  if (result.error) {
    throw new Error(`${command} ${args.join(" ")}: ${result.error.code ?? result.error.message} after ${timeout} ms`);
  }
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} (exit ${result.status}):\n${result.stdout}${result.stderr}`);
  }
  return result.stdout;
}

const [, , compiler, mode, ...extra] = process.argv;
if (!compiler || (mode && mode !== "--require-simulator") || extra.length) {
  throw new Error("Usage: node test/ios-simulator.mjs <pudu> [--require-simulator]");
}
function unavailable(reason) {
  if (mode === "--require-simulator") throw new Error(reason);
  console.log(`SKIP iOS simulator smoke: ${reason}`);
}
const xcrun = process.env.PUDU_XCRUN || "xcrun";
const identifier = `org.pudu.MobileForeignSmoke.${randomUUID()}`;

function smoke() {
  if (process.platform !== "darwin" || process.arch !== "arm64") {
    return unavailable("Apple silicon macOS required");
  }
  const probe = spawnSync(xcrun, ["--version"], { timeout: 10_000 });
  if (probe.error?.code === "ENOENT") {
    return unavailable("xcrun unavailable");
  }

  const { runtimes } = JSON.parse(run(xcrun, ["simctl", "list", "runtimes", "-j"], simulatorTimeout));
  const runtime = runtimes.filter((item) =>
    item.isAvailable && item.identifier.startsWith("com.apple.CoreSimulator.SimRuntime.iOS-")
  ).at(-1);
  if (!runtime) {
    return unavailable("no installed iOS simulator runtime");
  }
  const phone = runtime.supportedDeviceTypes.find((item) => item.productFamily === "iPhone");
  assert.ok(phone, `No iPhone device type for ${runtime.identifier}`);

  const root = mkdtempSync(join(tmpdir(), "pudu-ios-smoke-"));
  const existingDevice = process.env.PUDU_IOS_SIMULATOR_UDID;
  let device = existingDevice;
  let installed = false;
  try {
    const source = join(root, "Main.pudu");
    const library = join(root, "libMain.a");
    const app = join(root, "PuduSmoke.app");
    const host = join(root, "main.m");
    const shimSource = join(root, "shim.c");
    const hostShim = join(root, "libPuduSmokeShim.dylib");
    const framework = join(app, "Frameworks", "PuduSmokeShim.framework");
    const frameworkInstallName = "@rpath/PuduSmokeShim.framework/PuduSmokeShim";
    writeFileSync(shimSource, "#include <stdint.h>\nint32_t pudu_smoke_add(int32_t a, int32_t b) { return a + b; }\n");
    run(xcrun, ["--sdk", "macosx", "clang", "-dynamiclib", shimSource, "-o", hostShim]);
    const program = `module Main

foreign "c" {
  fn absolute symbol "abs" (value: Int32) -> Int32
  fn strlen(text: Str) -> UInt64
}

foreign "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation" {
  fn absoluteTime symbol "CFAbsoluteTimeGetCurrent" () -> Float64
}

foreign "${frameworkInstallName}" {
  fn add symbol "pudu_smoke_add" (a: Int32, b: Int32) -> Int32
}

fn main() -> Int {
  unsafe(foreign) {
    print("PUDU_SMOKE " + display(absolute(-42i32)) + " " + display(strlen("pudu")))
    print("PUDU_SMOKE CoreFoundation " + display(absoluteTime() > 0.0))
    print("PUDU_SMOKE EmbeddedFramework " + display(add(19i32, 23i32)))
  }
  0
}
`;
    writeFileSync(source, program.replace(frameworkInstallName, hostShim));
    const expected = run(resolve(compiler), ["run", source]).trim();
    assert.equal(expected, "PUDU_SMOKE 42 4\nPUDU_SMOKE CoreFoundation true\nPUDU_SMOKE EmbeddedFramework 42");
    writeFileSync(source, program);
    run(resolve(compiler), ["build", source, "--native", "--target", "ios-simulator-arm64", "-o", library]);
    mkdirSync(framework, { recursive: true });
    writeFileSync(host, `#include "pudu_program.h"
#include <stdio.h>
int main(int argc, char **argv) {
  @autoreleasepool {
    int status = pudu_program_run(argc, argv);
    printf("PUDU_SMOKE_STATUS %d\\n", status);
    return status;
  }
}
`);
    writeFileSync(join(app, "Info.plist"), `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>${identifier}</string>
<key>CFBundleExecutable</key><string>PuduSmoke</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>15.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
</dict></plist>
`);
    const sdk = run(xcrun, ["--sdk", "iphonesimulator", "--show-sdk-path"]).trim();
    const simulatorClang = ["--sdk", "iphonesimulator", "clang", "-target",
      "arm64-apple-ios15.0-simulator", "-isysroot", sdk, "-Wall", "-Wextra", "-Werror"];
    run(xcrun, [...simulatorClang, "-dynamiclib", "-install_name", frameworkInstallName,
      shimSource, "-o", join(framework, "PuduSmokeShim")]);
    writeFileSync(join(framework, "Info.plist"), `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>${identifier}.shim</string>
<key>CFBundleExecutable</key><string>PuduSmokeShim</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
</dict></plist>
`);
    run("codesign", ["--force", "--sign", "-", framework]);
    run(xcrun, [...simulatorClang, "-Wl,-rpath,@executable_path/Frameworks",
      host, library, "-framework", "Foundation", "-o", join(app, "PuduSmoke")]);
    run("codesign", ["--force", "--sign", "-", app]);
    if (!device) {
      device = run(xcrun, ["simctl", "create", "Pudu Foreign Smoke", phone.identifier, runtime.identifier]).trim();
      run(xcrun, ["simctl", "bootstatus", device, "-b"], 240_000);
    }
    run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
    installed = true;
    const lines = launch(device, identifier, "PUDU_SMOKE", "PUDU_SMOKE_STATUS");
    assert.deepEqual(lines, [...expected.split("\n"), "PUDU_SMOKE_STATUS 0"]);
    console.log(`${expected}\nPASS iOS simulator smoke (${device})`);
    mobileApp(device, simulatorClang, "Counter", [
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "3" }, labels: ["Count: 3"] }]);
    mobileApp(device, simulatorClang, "Form", [
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_TYPE: "Ada" }, labels: ["Hello, Ada (subscribed)"] },
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "1", SIMCTL_CHILD_PUDU_UI_TYPE: "Ada" }, labels: ["Hello, stranger"] }]);
    mobileApp(device, simulatorClang, "List", [
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "3", SIMCTL_CHILD_PUDU_UI_TYPE: "Milk" }, labels: ["3 items", "Milk 3", "Milk 1", "Milk 2"] }]);
  } finally {
    try {
      if (device && !existingDevice) {
        spawnSync(xcrun, ["simctl", "shutdown", device], { timeout: 30_000 });
        run(xcrun, ["simctl", "delete", device], 30_000);
      } else if (installed) {
        run(xcrun, ["simctl", "uninstall", device, identifier], 30_000);
      }
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
}

/* An example from examples/mobile, built only from Pudu with the iOS host
   adapter and run once per entry of `runs`: the host feeds it input from the
   entry's environment, asks it to stop, and reports its labels, its status
   and the time from main to the first frame. */
function mobileApp(device, simulatorClang, example, runs) {
  const root = mkdtempSync(join(tmpdir(), `pudu-ios-${example.toLowerCase()}-`));
  const app = join(root, `${example}.app`);
  const library = join(root, `lib${example}.a`);
  const bundle = `org.pudu.Mobile${example}.${randomUUID()}`;
  let installed = false;
  try {
    run(resolve(compiler), ["build", join(repository, "examples", "mobile", `${example}.pudu`),
      "--native", "--target", "ios-simulator-arm64", "-o", library]);
    mkdirSync(app);
    writeFileSync(join(app, "Info.plist"), `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>${bundle}</string>
<key>CFBundleExecutable</key><string>${example}</string>
<key>CFBundleName</key><string>${example}</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>15.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>UILaunchScreen</key><dict/>
</dict></plist>
`);
    const executable = join(app, example);
    run(xcrun, [...simulatorClang, "-fobjc-arc", "-O2", "-I", root,
      join(repository, "packages", "pudu", "v0.1", "host", "ios", "PuduHost.m"), library,
      "-framework", "UIKit", "-framework", "Foundation", "-o", executable]);
    run("codesign", ["--force", "--sign", "-", app]);
    run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
    installed = true;
    for (const { environment, labels } of runs) {
      const lines = launch(device, bundle, "PUDU_", "PUDU_PROGRAM_STATUS", environment);
      // The host reports labels in the order the screen shows them.
      assert.deepEqual(lines.filter((line) => line.startsWith("PUDU_LABEL ")), labels.map((label) => `PUDU_LABEL ${label}`),
        `${example} did not show ${labels.join(", ")}:\n${lines.join("\n")}`);
      assert.ok(lines.includes("PUDU_PROGRAM_STATUS 0"), `${example} did not finish:\n${lines.join("\n")}`);
      const firstFrame = lines.find((line) => line.startsWith("PUDU_FIRST_FRAME_MS "));
      assert.ok(firstFrame, `${example} reported no first frame:\n${lines.join("\n")}`);
      console.log(`PASS iOS ${example}: ${labels.join(", ")}, first frame ${firstFrame.split(" ")[1]} ms from main, `
        + `executable ${statSync(executable).size} bytes, program archive ${statSync(library).size} bytes`);
    }
  } finally {
    try {
      if (installed) run(xcrun, ["simctl", "uninstall", device, bundle], 30_000);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
}

/* The app's own status line proves it ran to completion. Only a launch that
   timed out or reported nothing is retried; any reported output is final. */
function launch(device, bundle, prefix, status, environment = {}) {
  const failures = [];
  for (let attempt = 1; attempt <= launchAttempts; attempt += 1) {
    try {
      const output = run(xcrun, ["simctl", "launch", "--console-pty", device, bundle], simulatorTimeout,
        { ...process.env, ...environment });
      const lines = output.split(/\r?\n/u).filter((line) => line.startsWith(prefix));
      if (lines.some((line) => line.startsWith(status))) return lines;
      failures.push(`attempt ${attempt}: no ${status} line:\n${output}`);
    } catch (problem) {
      failures.push(`attempt ${attempt}: ${problem.message}`);
    }
    spawnSync(xcrun, ["simctl", "terminate", device, bundle], { timeout: 30_000 });
  }
  throw new Error(`${bundle} did not report:\n${failures.join("\n")}`);
}

smoke();
