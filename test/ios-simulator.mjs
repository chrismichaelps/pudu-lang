import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync, writeSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { prebuild } from "./ios-app-builds.mjs";
import { objectiveCSmoke, swiftSmoke } from "./ios-foreign-apps.mjs";

// A cold hosted simulator can take minutes to install or launch its first app.
const simulatorTimeout = 300_000;
// A first boot of a device created here; a second family boots beside the phone and takes several minutes.
const bootTimeout = 600_000;
const appBuildTimeout = 300_000;
const launchAttempts = 2;

/* A line written to stdout before the next step starts. Every step blocks the
   event loop, and stdout to a pipe is otherwise written only when the loop
   runs, so a log read during the run would lag behind it. */
function say(line) {
  writeSync(1, `${line}\n`);
}

/* PUDU_IOS_ONLY narrows a run to the named parts, comma-separated: example
   names, "foreign" for the Objective-C and Swift smokes, "refusals" for the
   refused streams, and "matrix" for the device families. Unset, every part
   runs, as CI runs it. */
const only = process.env.PUDU_IOS_ONLY ? new Set(process.env.PUDU_IOS_ONLY.split(",").map((part) => part.trim())) : null;

/* PUDU_IOS_SHARD, "i/n", runs only the parts whose name hashes to shard i of
   n, so n jobs together run the whole suite. */
const [shard, shards] = (process.env.PUDU_IOS_SHARD || "1/1").split("/").map(Number);
function inShard(part) {
  let hash = 0;
  for (const code of Buffer.from(part)) hash = (hash * 31 + code) >>> 0;
  return hash % shards === shard - 1;
}

function wanted(part) { return (only === null || only.has(part)) && inShard(part); }

function selected(part) {
  if (wanted(part)) return true;
  say(`SKIP iOS ${part}`);
  return false;
}

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..");
// The counter imports Std.Mobile from this checkout, whichever compiler runs.
process.env.PUDU_LIB ??= join(repository, "packages", "pudu", "v0.1", "lib");

/* Runs one step to completion. Stdin is closed so no step waits on input,
   and a step past its timeout is killed outright rather than asked to stop. */
function run(command, args, timeout = 120_000, env = process.env) {
  const result = spawnSync(command, args, { encoding: "utf8", timeout, env, stdio: ["ignore", "pipe", "pipe"], killSignal: "SIGKILL" });
  if (result.error) {
    throw new Error(`${command} ${args.join(" ")}: ${result.error.code ?? result.error.message} after ${timeout} ms`);
  }
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} (exit ${result.status}):\n${result.stdout}${result.stderr}`);
  }
  return result.stdout;
}

/* Runs `body` with a local test server in its own process, since this script
   blocks on every step, when the example `part` is selected; `body` gets the server's base URL and a function that
   reads its request counts. */
function withFetchServer(part, body) {
  if (!wanted(part)) return undefined;
  const root = mkdtempSync(join(tmpdir(), "pudu-fetch-"));
  const record = join(root, "counts.json");
  const server = spawn(process.execPath, [join(repository, "test", "fetch-server.mjs"), record], { stdio: "ignore" });
  const pause = new Int32Array(new SharedArrayBuffer(4));
  try {
    for (let waited = 0; !existsSync(record) && waited < 10_000; waited += 50) Atomics.wait(pause, 0, 0, 50);
    const counts = () => JSON.parse(readFileSync(record, "utf8"));
    return body(`http://127.0.0.1:${counts().port}`, counts);
  } finally {
    server.kill();
    rmSync(root, { recursive: true, force: true });
  }
}

const [, , compiler, mode, ...extra] = process.argv;
if (!compiler || (mode && mode !== "--require-simulator") || extra.length) {
  throw new Error("Usage: node test/ios-simulator.mjs <pudu> [--require-simulator]");
}
function unavailable(reason) {
  if (mode === "--require-simulator") throw new Error(reason);
  say(`SKIP iOS simulator smoke: ${reason}`);
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
    say(`${expected}\nPASS iOS simulator smoke (${device})`);
    const apps = { run, launch, uninstall: uninstallFromReusedDevice, xcrun, compiler, identifier, simulatorTimeout };
    if (selected("foreign")) {
      objectiveCSmoke(apps, device, root, simulatorClang);
      swiftSmoke(apps, device, root, simulatorClang);
    }
    if (wanted("refusals")) refuseOccupiedOutput(root);
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
    refusedApp(device, root, "value on a label",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let label = Stream.create([], 0u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.number(label, 0u32, 3u32)))`,
      /pudu: a view stream set a value on a node that holds none: 0/u);
    refusedApp(device, root, "inverted slider bounds",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let slider = Stream.create([], 0u32, Stream.SLIDER)
  Host.apply(bytesOf(Stream.bounds(slider, 0u32, 10i32, 1i32, 1i32)))`,
      /pudu: a view stream set an inverted range or a step below one on node 0/u);
    refusedApp(device, root, "empty segment labels",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let segments = Stream.create([], 0u32, Stream.SEGMENTS)
  let none: Array[Str] = []
  Host.apply(bytesOf(Stream.options(segments, 0u32, &none)))`,
      /pudu: a view stream gave no options to node 0/u);
    mobileApp(device, "Pages", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_NAVIGATION_TEST: "1" },
      labels: ["Pops: 1", "Dismissals: 1"],
      layout: ["PUDU_NAV pushed", "PUDU_NAV popped once", "PUDU_NAV sheet shown", "PUDU_NAV sheet dismissed once",
        "PUDU_NAV sheet closed without echo"],
    }]);
    refusedApp(device, root, "repeated route ids",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let body = Stream.create(Stream.create([], 0u32, Stream.LABEL), 1u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.navigate(body, &[(1u32, 0u32, "A"), (1u32, 1u32, "B")], None)))`,
      /pudu: a view stream showed two routes with id 1/u);
    mobileApp(device, "Refresh", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_REFRESH_TEST: "1" },
      labels: ["Pulls: 2", "Insets: top true", ...Array.from({ length: 30 }, (_, index) => `Line ${index + 1}`)],
      layout: ["PUDU_REFRESH insets reported", "PUDU_REFRESH answered pull refreshing", "PUDU_REFRESH finished by the program",
        "PUDU_REFRESH unanswered pull stopped"],
    }]);
    withFetchServer("Remote", (base, counts) => {
      mobileApp(device, "Remote", [{
        environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_FETCH_TEST: "1", SIMCTL_CHILD_PUDU_FETCH_BASE: base },
        labels: ["Profile: 200 profile body", "Limited: 200 limited body"],
        layout: ["PUDU_FETCH loaded"],
      }]);
      // Two descriptions of the profile share one request; the rate-limited
      // path is asked once, refused, and asked again after Retry-After.
      const asked = counts();
      assert.equal(asked.profile, 1, `profile was requested ${asked.profile} times`);
      assert.equal(asked.limited, 2, `limited was requested ${asked.limited} times`);
      say("PASS iOS Remote requests: profile once, limited twice");
    });
    withFetchServer("Gallery", (base, counts) => {
      // A bundled and a served image show at their own pixel size, a missing
      // one reports a failure, and an image moved off a slow source before it
      // answered shows its new source and never the slow one.
      mobileApp(device, "Gallery", [{
        environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_IMAGE_TEST: "1", SIMCTL_CHILD_PUDU_FETCH_BASE: base },
        labels: ["Loaded: 3", "Failed: 1", "Moved: true"],
        layout: ["PUDU_IMAGE 1 1 48x48", "PUDU_IMAGE 2 1 96x96", "PUDU_IMAGE 3 0 0x0", "PUDU_IMAGE 4 1 48x48"],
      }]);
      const asked = counts();
      assert.equal(asked.photo, 1, `the photo was requested ${asked.photo} times`);
      say("PASS iOS Gallery requests: photo once");
    });
    // The copied text pastes back, a URL no app handles reports false, the
    // share sheet shows and its cancellation reports false, and the status
    // bar takes the light text the program asked for.
    mobileApp(device, "Services", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_SYSTEM_TEST: "1" },
      labels: ["Pasted: from Pudu", "Opened: false", "Shared: false"],
      layout: ["PUDU_SYSTEM share shown", "PUDU_SYSTEM status light shown"],
    }]);
    // A granted camera, a refused microphone and contacts never asked report
    // as Granted, Blocked and NotAsked; requesting the granted camera answers
    // at once, without a prompt.
    // The person picks the second tab and back, pushes and pops inside the
    // first, and dismisses a sheet; each is reported once.
    // The manifest's identity reaches the bundle, and a link in the
    // application's own scheme comes back to it as Linked.
    // Plain and secure values persist from one launch to the next, and a
    // removed key reads as absent.
    mobileApp(device, "Vault", [
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0" }, labels: ["Launches: 1", "Token: s3cret", "Temporary: none"] },
      { environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0" }, labels: ["Launches: 2", "Token: s3cret", "Temporary: none"] },
    ]);
    // The device describes itself as iOS at the default text scale, reports
    // a link the simulator reaches the network through, and keeps the screen
    // awake while in front.
    mobileApp(device, "About", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_DEVICE_TEST: "1" },
      labels: ["Platform: ios", /^Version: \d+(\.\d+)*$/u, /^Model: \S+$/u, /^Locale: [A-Za-z]{2,3}(-\w+)*$/u, /^Zone: \S+$/u,
        "Scale: 100", "Online: true", /^Link: (Wifi|Cellular|Wired)$/u],
      layout: ["PUDU_DEVICE awake yes"],
    }]);
    refusedApp(device, root, "network watching word 2",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  Host.apply(bytesOf(Stream.network([], 2u32)))`,
      /pudu: a view stream set network watching to 2/u);
    // With location allowed and set, one position arrives and shows in
    // ten-millionths of a degree; with it revoked, the position answers as none.
    mobileApp(device, "Where", [
      {
        environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_LOCATION_TEST: "1" },
        privacy: [["grant", "location"]],
        location: "18.4655,-66.1057",
        labels: ["Permission: Granted", "Latitude: 184655000", "Longitude: -661057000", /^Fixes: [1-9]\d*$/u],
        layout: ["PUDU_LOCATION answered yes"],
      },
      {
        environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_LOCATION_TEST: "1" },
        privacy: [["revoke", "location"]],
        labels: ["Permission: Blocked", "Latitude: none", "Fixes: 0"],
        layout: ["PUDU_LOCATION answered yes"],
      },
    ], "where");
    // The battery, authentication and speech each answer once; the simulator
    // has no passcode, so the person cannot be confirmed, and no accelerometer.
    mobileApp(device, "Toolbox", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_SERVICES_TEST: "1" },
      labels: [/^Battery: (unknown|unplugged|charging|full|\d+% \w+)$/u, "Authenticated: false", /^Spoke: (true|false)$/u, "Motion: none",
        "Photo: none", "Reminders tapped: 0"],
      layout: ["PUDU_SERVICES authenticated yes powered yes spoke yes"],
    }], "toolbox");
    // An empty page loads and answers once; the chime and the clip are not
    // bundled, so the chime ends at once and the clip stays blank.
    mobileApp(device, "Viewer", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_WEB_TEST: "1" },
      labels: ["Loaded: true", "Backs: 0", /^Sounds ended: [01]$/u],
      layout: ["PUDU_WEB loaded yes"],
    }]);
    // At rest, before any picker opens, every answer reads as none.
    mobileApp(device, "Picker", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0" },
      labels: ["Contact: none", "Document: none", "Photo: none", "Note: none"],
    }], "pick");
    // At rest, before any sheet opens, every answer reads as none.
    mobileApp(device, "Outbox", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0" },
      labels: ["Event: none", "Mail: none", "Message: none"],
    }]);
    refusedApp(device, root, "recording word 2",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Request as Request", `  Host.apply(bytesOf(Request.record([], 1u32, 2u32)))`,
      /pudu: a view stream set recording to 2/u);
    refusedApp(device, root, "load on a label",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let label = Stream.create([], 0u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.load(label, 0u32, "about:blank")))`,
      /pudu: a view stream loaded a page into a node that is not a web view: 0/u);
    refusedApp(device, root, "brightness above 100",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Request as Request", `  Host.apply(bytesOf(Request.brightness([], 101u32)))`,
      /pudu: a view stream set brightness to 101/u);
    refusedApp(device, root, "unknown orientation",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Request as Request", `  Host.apply(bytesOf(Request.orientation([], 3u32)))`,
      /pudu: a view stream locked unknown orientation 3/u);
    refusedApp(device, root, "unknown location accuracy",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  Host.apply(bytesOf(Stream.locate([], 1u32, 7u32)))`,
      /pudu: a view stream used unknown location accuracy 7/u);
    mobileApp(device, "Links", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_LINK_TEST: "pudulinks://hello?from=test" },
      labels: ["Link: pudulinks://hello?from=test"],
      layout: ["PUDU_SYSTEM link opened"],
    }], "links", "dev.pudu.links");
    mobileApp(device, "Tabs", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_TABS_TEST: "1" },
      labels: ["Selected: 1", "Pops: 1", "Dismissals: 1"],
      layout: ["PUDU_TABS picked", "PUDU_TABS pushed", "PUDU_TABS popped once", "PUDU_TABS sheet dismissed once"],
    }]);
    refusedApp(device, root, "a selected tab that is not shown",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let body = Stream.create([], 0u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.tabs(body, &[(1u32, "A", "house", [(10u32, 0u32, "A")])], 2u32, None)))`,
      /pudu: a view stream selected a tab that is not shown: 2/u);
    mobileApp(device, "Permissions", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_PERMISSION_TEST: "1" },
      privacy: [["grant", "camera"], ["revoke", "microphone"], ["reset", "contacts"]],
      labels: ["Camera: Granted", "Microphone: Blocked", "Contacts: NotAsked"],
      layout: ["PUDU_PERMISSION 0 1", "PUDU_PERMISSION 1 5", "PUDU_PERMISSION 7 0"],
    }], "permissions");
    refusedApp(device, root, "unknown status bar style",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  Host.apply(bytesOf(Stream.status([], 7u32, false)))`,
      /pudu: a view stream used unknown status bar style 7/u);
    refusedApp(device, root, "source on a label",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let label = Stream.create([], 0u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.source(label, 0u32, 0u32, 0u32, "pudu.png")))`,
      /pudu: a view stream set a source on a node that is not an image: 0/u);
    refusedApp(device, root, "unknown image scaling",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let image = Stream.create([], 0u32, Stream.IMAGE)
  Host.apply(bytesOf(Stream.source(image, 0u32, 0u32, 9u32, "pudu.png")))`,
      /pudu: a view stream used unknown image scaling 9/u);
    refusedApp(device, root, "refresh on a label",
      "import Std.Mobile.Host as Host\nimport Std.Mobile.Stream as Stream", `  let label = Stream.create([], 0u32, Stream.LABEL)
  Host.apply(bytesOf(Stream.refresh(label, 0u32, 1u32, false)))`,
      /pudu: a view stream refreshed a node that does not scroll: 0/u);
    if (selected("matrix")) familyMatrix(runtime);
    mobileApp(device, "Glass", [glassRun("glass")]);
    mobileApp(device, "Showcase", [{
      environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_CAPABILITY_TEST: "1" },
      labels: [
        "Gestures: press began, pan changed 12 -7, pinch changed 1500, rotation changed 785, swipe right",
        "Size: compact regular",
        // The launch's own activation depends on the simulator bringing the
        // app to the front; the resign and return the self-test posts must follow it.
        /^Phases: (active )?inactive active$/u,
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
  // Each value control is driven once; its label shows the value its event carried.
  Controls: [{
    environment: { SIMCTL_CHILD_PUDU_UI_SELFTEST: "0", SIMCTL_CHILD_PUDU_UI_CONTROLS_TEST: "1" },
    labels: ["Volume: 100", "Count: 3", "Size: Large", "Fruit: Plum", "Moment: 1000000000", "Notes: Notes", "Search: pudu",
      "Page: 2", "Color: 4286578943"],
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
      say(`PASS iOS ${family} matrix (${type.name}, ${runtime.name})`);
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
    say("SKIP iOS material fallback: no runtime older than iOS 26 is installed");
    return;
  }
  const phone = older.supportedDeviceTypes.find((item) => item.productFamily === "iPhone");
  assert.ok(phone, `No iPhone device type for ${older.identifier}`);
  const device = run(xcrun, ["simctl", "create", "Pudu Material Fallback", phone.identifier, older.identifier]).trim();
  try {
    run(xcrun, ["simctl", "bootstatus", device, "-b"], bootTimeout);
    mobileApp(device, "Glass", [glassRun("blur")]);
    say(`PASS iOS material fallback (${older.name})`);
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
  say("PASS iOS occupied application output refused");
}

/* An example from examples/mobile, built only from Pudu with the iOS host
   adapter and run once per entry of `runs`: the host feeds it input from the
   entry's environment, asks it to stop, and reports its labels, its status
   and the time from main to the first frame. */
function mobileApp(device, example, runs, directory = "", bundle = `org.pudu.${example}`) {
  if (!selected(example)) return;
  const app = built(join(directory, example), buildWait);
  let installed = false;
  try {
    const executable = join(app, example);
    run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
    installed = true;
    for (const { environment, labels, layout, privacy = [], location } of runs) {
      // Each entry presets one service's answer, as the person's earlier choice would.
      for (const [action, service] of privacy) run(xcrun, ["simctl", "privacy", device, action, service, bundle], simulatorTimeout);
      // A simulated position, as the device would report it.
      if (location) run(xcrun, ["simctl", "location", device, "set", location], simulatorTimeout);
      const lines = launch(device, bundle, "PUDU_", "PUDU_PROGRAM_STATUS", environment);
      // The host reports labels in the order the screen shows them; a pattern
      // stands for a label whose text depends on the machine.
      const shown = lines.filter((line) => line.startsWith("PUDU_LABEL ")).map((line) => line.slice("PUDU_LABEL ".length));
      assert.ok(shown.length === labels.length
        && labels.every((label, index) => (label instanceof RegExp ? label.test(shown[index]) : label === shown[index])),
        `${example} did not show ${labels.join(", ")}:\n${lines.join("\n")}`);
      assert.ok(lines.includes("PUDU_PROGRAM_STATUS 0"), `${example} did not finish:\n${lines.join("\n")}`);
      if (layout) {
        assert.deepEqual(lines.filter((line) => /^PUDU_(VIEWPORT|KEYBOARD|THEME|LIST|MATERIAL|ALERT|HAPTIC|ACCESS|MOTION|NAV|REFRESH|FETCH|IMAGE|SYSTEM|PERMISSION|TABS|DEVICE|LOCATION|SERVICES|WEB) /.test(line)), layout,
          `${example} did not report the expected layout and theme:\n${lines.join("\n")}`);
      }
      const firstFrame = lines.find((line) => line.startsWith("PUDU_FIRST_FRAME_MS "));
      assert.ok(firstFrame, `${example} reported no first frame:\n${lines.join("\n")}`);
      say(`PASS iOS ${example}: ${labels.join(", ")}, first frame ${firstFrame.split(" ")[1]} ms from main, `
        + `executable ${statSync(executable).size} bytes`);
    }
  } finally {
    if (installed) uninstallFromReusedDevice(device, bundle);
  }
}

/* A program whose stream the host must refuse: it aborts with `refusal` and
   never reports a first frame or a clean status. */
function refusedApp(device, scratch, what, imports, body, refusal) {
  if (!wanted("refusals")) return;
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
    const launched = spawnSync(xcrun, ["simctl", "launch", "--console-pty", "--terminate-running-process", device, bundle],
      { encoding: "utf8", timeout: simulatorTimeout });
    if (launched.error) throw launched.error;
    const output = launched.stdout + launched.stderr;
    assert.match(output, refusal);
    assert.doesNotMatch(output, /PUDU_FIRST_FRAME_MS|PUDU_PROGRAM_STATUS 0/u);
    say(`PASS iOS ${what} refused`);
  } finally {
    uninstallFromReusedDevice(device, bundle);
  }
}

/* The app's own status line proves it ran to completion. Only a launch that
   timed out or reported nothing is retried; any reported output is final. */
function launch(device, bundle, prefix, status, environment = {}) {
  const failures = [];
  for (let attempt = 1; attempt <= launchAttempts; attempt += 1) {
    say(`LAUNCH iOS ${bundle} attempt ${attempt}`);
    try {
      // A retry ends whatever an earlier attempt left running, whose output
      // would otherwise reach this attempt's console as well.
      const output = run(xcrun, ["simctl", "launch", "--console-pty", "--terminate-running-process", device, bundle], simulatorTimeout,
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

/* Each example the run launches, named in the mobileApp calls above or in
   the family table, with
   its source beside the other examples or in a folder of its own; the key
   is the folder and name mobileApp asks for. */
function exampleEntries() {
  const examples = join(repository, "examples", "mobile");
  const calls = readFileSync(fileURLToPath(import.meta.url), "utf8").matchAll(/mobileApp\(device, "(\w+)"/gu);
  const folders = ["", ...readdirSync(examples).filter((entry) => statSync(join(examples, entry)).isDirectory())];
  const entries = [];
  // The family runs name their examples in a table rather than in a call.
  for (const name of new Set([...[...calls].map((call) => call[1]), ...Object.keys(familyRuns)])) {
    if (!wanted(name)) continue;
    const folder = folders.find((candidate) => existsSync(join(examples, candidate, `${name}.pudu`)));
    if (folder !== undefined) entries.push({ key: join(folder, name), source: join(examples, folder, `${name}.pudu`) });
  }
  return entries;
}

// The longest a step waits for its app; builds queue behind one another.
const buildWait = 1_800_000;
const built = prebuild(repository, resolve(compiler), process.env.PUDU_LIB, exampleEntries());

smoke();
