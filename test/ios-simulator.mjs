import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// A cold hosted simulator can take minutes to install or launch its first app.
const simulatorTimeout = 300_000;
// A first boot of a device created here; a second family boots beside the phone and takes several minutes.
const bootTimeout = 600_000;
const appBuildTimeout = 300_000;
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
      run(xcrun, ["simctl", "bootstatus", device, "-b"], bootTimeout);
    }
    run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
    installed = true;
    const lines = launch(device, identifier, "PUDU_SMOKE", "PUDU_SMOKE_STATUS");
    assert.deepEqual(lines, [...expected.split("\n"), "PUDU_SMOKE_STATUS 0"]);
    console.log(`${expected}\nPASS iOS simulator smoke (${device})`);
    objectiveCSmoke(device, root, sdk, simulatorClang);
    refuseOccupiedOutput(root);
    familyApps(device, "Counter");
    mobileApp(device, "Form", [
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_TYPE: "Ada" }, labels: ["Hello, Ada (subscribed)"] },
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "1", SIMCTL_CHILD_PUDU_UI_TYPE: "Ada" }, labels: ["Hello, stranger"] }]);
    mobileApp(device, "List", [
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "3", SIMCTL_CHILD_PUDU_UI_TYPE: "Milk" }, labels: ["3 items", "Milk 3", "Milk 1", "Milk 2"] }]);
    familyApps(device, "Feed");
    mobileApp(device, "Themed", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_THEME_TEST: "1" },
      labels: ["Themed"],
      layout: ["PUDU_THEME ink light #1F2A44FF dark #E8EEFFFF", "PUDU_THEME appearance dark", "PUDU_THEME type grows"],
    }]);
    familyApps(device, "Catalog");
    refusedApp(device, root, "invalid group placement",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let empty: Array[UInt8] = []
  Host.apply(bytesOf(empty))
  let parent = Stream.create([], 0u32, Stream.LABEL)
  let child = Stream.create(parent, 1u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.append(child, 0u32, 1u32)))`,
      /pudu: a view stream placed a child in a node that holds nothing: 0/u);
    refusedApp(device, root, "text style on a group",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Theme as Theme\nimport Std.Mobile.View as View", `  let (_, built) = View.mount(&View.Styled(Theme.Body, View.Column([])))
  Host.apply(built)`,
      /pudu: a view stream styled a node that shows no text: 0/u);
    refusedApp(device, root, "list range on a label",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let label = Stream.create([], 0u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.range(label, 0u32, 10u32, 0u32)))`,
      /pudu: a view stream shaped a node that is not a list: 0/u);
    familyMatrix(runtime);
    mobileApp(device, "Glass", [glassRun("glass")]);
    mobileApp(device, "Showcase", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_CAPABILITY_TEST: "1" },
      labels: [
        "Gestures: press began, pan changed 12 -7, pinch changed 1500, rotation changed 785, swipe right",
        "Size: compact regular",
        "Phases: active inactive active",
        "Picked: Delete",
        "Chose: Start",
        "Row 1",
        "Row 2",
      ],
      layout: [
        "PUDU_ALERT Welcome",
        "PUDU_HAPTIC 5",
        "PUDU_ACCESS header=yes hint=Shows recognized gestures value=swipe right",
        "PUDU_MOTION animated",
      ],
    }]);
    fallbackGlass(runtimes);
  } finally {
    try {
      if (device && !existingDevice) {
        deletePrivateDevice(device);
      } else if (installed) {
        uninstallFromReusedDevice(device, identifier);
      }
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
}

/* The runs every device family must pass: layout, keyboard avoidance and a
   recycling grid are where screen size and idiom differ. */
const familyRuns = {
  Counter: [{ environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "3" }, labels: ["Count: 3"] }],
  Feed: [{
    environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_KEYBOARD_TEST: "1" },
    labels: Array.from({ length: 40 }, (_, index) => `Row ${index + 1}`),
    layout: ["PUDU_VIEWPORT safe and scrollable", "PUDU_KEYBOARD visible field", "PUDU_KEYBOARD restored"],
  }],
  Catalog: [{
    environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_LIST_TEST: "1" },
    // Scrolled to the end, the window is clamped to the last 120 items.
    labels: Array.from({ length: 120 }, (_, index) => `Item ${881 + index}`),
    layout: ["PUDU_LIST reached Item 1000", "PUDU_LIST reused"],
  }],
};

function familyApps(device, example) {
  mobileApp(device, example, familyRuns[example]);
}

/* One device of every family the runtime supports besides the iPhone, which
   ran everything above. A family introduced by a new runtime is exercised as
   soon as that runtime is installed. Each device is private and deleted. */
function familyMatrix(runtime) {
  const families = new Map();
  for (const type of runtime.supportedDeviceTypes) {
    if (type.productFamily !== "iPhone" && !families.has(type.productFamily)) families.set(type.productFamily, type);
  }
  for (const [family, type] of families) {
    const device = run(xcrun, ["simctl", "create", `Pudu ${family} Matrix`, type.identifier, runtime.identifier]).trim();
    try {
      run(xcrun, ["simctl", "bootstatus", device, "-b"], bootTimeout);
      for (const example of Object.keys(familyRuns)) familyApps(device, example);
      console.log(`PASS iOS ${family} matrix (${type.name}, ${runtime.name})`);
    } finally {
      deletePrivateDevice(device);
    }
  }
}

function glassRun(realization) {
  return {
    environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_MATERIAL_TEST: "1" },
    labels: ["Glass"],
    layout: [`PUDU_MATERIAL ${realization}`],
  };
}

/* The same app on the oldest installed runtime before iOS 26 must take the
   blur fallback: the glass branch is compiled in, and the run-time gate
   declines it. */
function fallbackGlass(runtimes) {
  const older = runtimes.find((item) =>
    item.isAvailable && item.identifier.startsWith("com.apple.CoreSimulator.SimRuntime.iOS-") && Number(item.version.split(".")[0]) < 26);
  if (!older) {
    console.log("SKIP iOS material fallback: no runtime older than iOS 26 is installed");
    return;
  }
  const phone = older.supportedDeviceTypes.find((item) => item.productFamily === "iPhone");
  assert.ok(phone, `No iPhone device type for ${older.identifier}`);
  const device = run(xcrun, ["simctl", "create", "Pudu Material Fallback", phone.identifier, older.identifier]).trim();
  try {
    run(xcrun, ["simctl", "bootstatus", device, "-b"], bootTimeout);
    mobileApp(device, "Glass", [glassRun("blur")]);
    console.log(`PASS iOS material fallback (${older.name})`);
  } finally {
    deletePrivateDevice(device);
  }
}

function deletePrivateDevice(device) {
  spawnSync(xcrun, ["simctl", "shutdown", device], { timeout: simulatorTimeout });
  run(xcrun, ["simctl", "delete", device], simulatorTimeout);
}

function uninstallFromReusedDevice(device, bundle) {
  if (device === process.env.PUDU_IOS_SIMULATOR_UDID) {
    run(xcrun, ["simctl", "uninstall", device, bundle], simulatorTimeout);
  }
}

function refuseOccupiedOutput(scratch) {
  const source = join(scratch, "Collision.pudu");
  const occupied = join(scratch, "Occupied.app");
  const marker = join(occupied, "keep.txt");
  writeFileSync(source, "module Collision\n\nfn main() -> Int { 0 }\n");
  mkdirSync(occupied);
  writeFileSync(marker, "existing data");
  const build = ["build", source, "--native", "--target", "ios-simulator-arm64", "--app", "-o", occupied];
  assert.throws(() => run(resolve(compiler), build, appBuildTimeout), /E6006.*application output already exists/s);
  assert.equal(readFileSync(marker, "utf8"), "existing data");
  console.log("PASS iOS occupied application output refused");
}

/* An example from examples/mobile, built only from Pudu with the iOS host
   adapter and run once per entry of `runs`: the host feeds it input from the
   entry's environment, asks it to stop, and reports its labels, its status
   and the time from main to the first frame. */
function mobileApp(device, example, runs) {
  const root = mkdtempSync(join(tmpdir(), `pudu-ios-${example.toLowerCase()}-`));
  const app = join(root, `${example}.app`);
  const bundle = `org.pudu.${example}`;
  let installed = false;
  try {
    const build = ["build", join(repository, "examples", "mobile", `${example}.pudu`),
      "--native", "--target", "ios-simulator-arm64", "--app", "-o"];
    run(resolve(compiler), [...build, app], appBuildTimeout);
    const executable = join(app, example);
    run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
    installed = true;
    for (const { environment, labels, layout } of runs) {
      const lines = launch(device, bundle, "PUDU_", "PUDU_PROGRAM_STATUS", environment);
      // The host reports labels in the order the screen shows them.
      assert.deepEqual(lines.filter((line) => line.startsWith("PUDU_LABEL ")), labels.map((label) => `PUDU_LABEL ${label}`),
        `${example} did not show ${labels.join(", ")}:\n${lines.join("\n")}`);
      assert.ok(lines.includes("PUDU_PROGRAM_STATUS 0"), `${example} did not finish:\n${lines.join("\n")}`);
      if (layout) {
        assert.deepEqual(lines.filter((line) => /^PUDU_(VIEWPORT|KEYBOARD|THEME|LIST|MATERIAL|ALERT|HAPTIC|ACCESS|MOTION) /.test(line)), layout,
          `${example} did not report the expected layout and theme:\n${lines.join("\n")}`);
      }
      const firstFrame = lines.find((line) => line.startsWith("PUDU_FIRST_FRAME_MS "));
      assert.ok(firstFrame, `${example} reported no first frame:\n${lines.join("\n")}`);
      console.log(`PASS iOS ${example}: ${labels.join(", ")}, first frame ${firstFrame.split(" ")[1]} ms from main, `
        + `executable ${statSync(executable).size} bytes`);
    }
  } finally {
    try {
      if (installed) uninstallFromReusedDevice(device, bundle);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
}

/* A program whose stream the host must refuse: it aborts with `refusal` and
   never reports a first frame or a clean status. */
function refusedApp(device, scratch, what, imports, body, refusal) {
  const name = `Refused${randomUUID().replaceAll("-", "")}`;
  const source = join(scratch, `${name}.pudu`);
  const app = join(scratch, `${name}.app`);
  const bundle = `org.pudu.${name}`;
  writeFileSync(source, `module ${name}

${imports}

fn main() -> Int {
${body}
  0
}
`);
  run(resolve(compiler), ["build", source, "--native", "--target", "ios-simulator-arm64", "--app", "-o", app], appBuildTimeout);
  run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
  try {
    const launched = spawnSync(xcrun, ["simctl", "launch", "--console-pty", device, bundle],
      { encoding: "utf8", timeout: simulatorTimeout });
    if (launched.error) throw launched.error;
    const output = launched.stdout + launched.stderr;
    assert.match(output, refusal);
    assert.doesNotMatch(output, /PUDU_FIRST_FRAME_MS|PUDU_PROGRAM_STATUS 0/u);
    console.log(`PASS iOS ${what} refused`);
  } finally {
    uninstallFromReusedDevice(device, bundle);
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

/* Foundation sends inside an autorelease pool, a block run during a call and
   one kept by a queue, and a delegate the notification center calls. The
   macOS interpreter's output is the expectation the simulator app must meet. */
function objectiveCSmoke(device, root, sdk, simulatorClang) {
  const bundle = `${identifier}.objc`;
  mkdirSync(join(root, "objc"));
  const source = join(root, "objc", "Main.pudu");
  const library = join(root, "libObjc.a");
  const app = join(root, "PuduObjc.app");
  const host = join(root, "objc.m");
  writeFileSync(source, `module Main

foreign "/System/Library/Frameworks/Foundation.framework/Foundation" {
  class StringObject symbol "NSString"
  class Center symbol "NSNotificationCenter"
  type Notice
  type Pool
  callback Posted(context, note: borrowed Notice) -> ()
  callbacks Events{posted: Posted}
  delegate Observer symbol "PuduSmokeObserver" for Events {
    posted "noticePosted:"
  }
  fn stringFrom selector "stringWithUTF8String:" on StringObject (text: Str) -> borrowed StringObject
  fn length selector "length" (receiver: StringObject) -> UInt64
  fn center selector "defaultCenter" on Center () -> borrowed Center
  fn observe selector "addObserver:selector:name:object:" (receiver: Center, observer: Observer, action: UInt64, name: StringObject, sender: UInt64) -> ()
  fn post selector "postNotificationName:object:" (receiver: Center, name: StringObject, sender: UInt64) -> ()
  fn selectorNamed symbol "sel_registerName" (name: Str) -> UInt64
  fn poolPush symbol "objc_autoreleasePoolPush" () -> owned Pool by poolPop
  fn poolPop symbol "objc_autoreleasePoolPop" (pool: Pool) -> ()
}

foreign "/usr/lib/libSystem.B.dylib" {
  type Queue
  callback Work(context) -> ()
  fn queueNew symbol "dispatch_queue_create" (label: Str, attributes: UInt64) -> owned Queue by queueRelease
  fn queueRelease symbol "dispatch_release" (queue: Queue) -> ()
  fn runNow symbol "dispatch_sync" (queue: Queue, work: block Work) -> ()
  fn runLater symbol "dispatch_async" (queue: Queue, work: block Work) -> ()
}

type Handlers = { posted: fn(Notice) -> () }

fn heard(note: Notice) -> () {
  let _shown = print("PUDU_OBJC delegate")
  ()
}

fn ran() -> () {
  let _shown = print("PUDU_OBJC block")
  ()
}

fn main() -> Int {
  unsafe(foreign) {
    let pool = poolPush()
    print("PUDU_OBJC length " + display(length(stringFrom("pudu"))))
    poolPop(pool)
    let queue = queueNew("pudu.smoke", 0u64)
    let work = Work(ran)
    runLater(queue, work)
    runNow(queue, work)
    let _work = work.unregister()
    queueRelease(queue)
    let events = Events(Handlers{posted: heard})
    let observer = Observer(events)
    let name = stringFrom("PuduSmokeNotice")
    observe(center(), observer, selectorNamed("noticePosted:"), name, 0u64)
    post(center(), name, 0u64)
  }
  0
}
`);
  const [, , compiler] = process.argv;
  const expected = run(resolve(compiler), ["run", source]).trim();
  assert.equal(expected,
    "PUDU_OBJC length 4\nPUDU_OBJC block\nPUDU_OBJC block\nPUDU_OBJC delegate");
  run(resolve(compiler), ["build", source, "--native", "--target", "ios-simulator-arm64", "-o", library]);
  mkdirSync(app, { recursive: true });
  writeFileSync(host, `#include "pudu_program.h"
#include <stdio.h>
int main(int argc, char **argv) {
  @autoreleasepool {
    int status = pudu_program_run(argc, argv);
    printf("PUDU_OBJC_STATUS %d\\n", status);
    return status;
  }
}
`);
  writeFileSync(join(app, "Info.plist"), `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>${bundle}</string>
<key>CFBundleExecutable</key><string>PuduObjc</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>15.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
</dict></plist>
`);
  run(xcrun, [...simulatorClang, host, library, "-framework", "Foundation", "-o", join(app, "PuduObjc")]);
  run("codesign", ["--force", "--sign", "-", app]);
  try {
    run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
    const lines = launch(device, bundle, "PUDU_OBJC", "PUDU_OBJC_STATUS");
    assert.deepEqual(lines, [...expected.split("\n"), "PUDU_OBJC_STATUS 0"]);
    console.log(`${expected}\nPASS iOS Objective-C smoke`);
  } finally {
    uninstallFromReusedDevice(device, bundle);
  }
}

smoke();
