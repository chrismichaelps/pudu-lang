import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

function run(command, args, timeout = 120_000) {
  const result = spawnSync(command, args, { encoding: "utf8", timeout });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} (exit ${result.status}):\n${result.stdout}${result.stderr}`);
  }
  return result.stdout;
}

const compiler = process.argv[2];
if (!compiler) throw new Error("Usage: node test/ios-simulator.mjs <pudu>");
const xcrun = process.env.PUDU_XCRUN || "xcrun";
const identifier = `org.pudu.MobileForeignSmoke.${randomUUID()}`;

function smoke() {
  if (process.platform !== "darwin" || process.arch !== "arm64") {
    console.log("SKIP iOS simulator smoke: Apple silicon macOS required");
    return;
  }
  const probe = spawnSync(xcrun, ["--version"], { timeout: 10_000 });
  if (probe.error?.code === "ENOENT") {
    console.log("SKIP iOS simulator smoke: xcrun unavailable");
    return;
  }

  const { runtimes } = JSON.parse(run(xcrun, ["simctl", "list", "runtimes", "-j"]));
  const runtime = runtimes.filter((item) =>
    item.isAvailable && item.identifier.startsWith("com.apple.CoreSimulator.SimRuntime.iOS-")
  ).at(-1);
  if (!runtime) {
    console.log("SKIP iOS simulator smoke: no installed iOS simulator runtime");
    return;
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
    writeFileSync(source, `module Main

foreign "c" {
  fn absolute symbol "abs" (value: Int32) -> Int32
  fn strlen(text: Str) -> UInt64
}

foreign "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation" {
  fn absoluteTime symbol "CFAbsoluteTimeGetCurrent" () -> Float64
}

fn main() -> Int {
  unsafe(foreign) {
    print("PUDU_SMOKE " + display(absolute(-42i32)) + " " + display(strlen("pudu")))
    print("PUDU_SMOKE CoreFoundation " + display(absoluteTime() > 0.0))
  }
  0
}
`);
    const expected = run(resolve(compiler), ["run", source]).trim();
    assert.equal(expected, "PUDU_SMOKE 42 4\nPUDU_SMOKE CoreFoundation true");
    run(resolve(compiler), ["build", source, "--native", "--target", "ios-simulator-arm64", "-o", library]);
    mkdirSync(app);
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
    run(xcrun, ["--sdk", "iphonesimulator", "clang", "-target",
      "arm64-apple-ios15.0-simulator", "-isysroot", sdk, "-Wall", "-Wextra",
      "-Werror", host, library, "-framework", "Foundation", "-o", join(app, "PuduSmoke")]);
    run("codesign", ["--force", "--sign", "-", app]);
    if (!device) {
      device = run(xcrun, ["simctl", "create", "Pudu Foreign Smoke", phone.identifier, runtime.identifier]).trim();
      run(xcrun, ["simctl", "bootstatus", device, "-b"], 240_000);
    }
    run(xcrun, ["simctl", "install", device, app]);
    installed = true;
    const output = run(xcrun, ["simctl", "launch", "--console-pty", device, identifier]);
    assert.deepEqual(output.split(/\r?\n/u).filter((line) => line.startsWith("PUDU_SMOKE")),
      [...expected.split("\n"), "PUDU_SMOKE_STATUS 0"]);
    console.log(`${expected}\nPASS iOS simulator smoke (${device})`);
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

smoke();
