import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { swiftExpected, swiftProgram, swiftSource } from "./swift-counter.mjs";

// Simulator apps whose Pudu code calls platform code through the foreign
// interface. Each one's macOS interpreter output is what the app must print.

function appInfo(bundle, executable) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>${bundle}</string>
<key>CFBundleExecutable</key><string>${executable}</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>15.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
</dict></plist>
`;
}

function hostMain(marker) {
  return `#include "pudu_program.h"
#include <stdio.h>
int main(int argc, char **argv) {
  @autoreleasepool {
    int status = pudu_program_run(argc, argv);
    printf("${marker}_STATUS %d\\n", status);
    return status;
  }
}
`;
}

/* Foundation sends inside an autorelease pool, a block run during a call and
   one kept by a queue, and a delegate the notification center calls. The
   macOS interpreter's output is the expectation the simulator app must meet. */
export function objectiveCSmoke(apps, device, root, simulatorClang) {
  const { run, compiler, identifier } = apps;
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
  const expected = run(resolve(compiler), ["run", source]).trim();
  assert.equal(expected,
    "PUDU_OBJC length 4\nPUDU_OBJC block\nPUDU_OBJC block\nPUDU_OBJC delegate");
  run(resolve(compiler), ["build", source, "--native", "--target", "ios-simulator-arm64", "-o", library]);
  installAndCheck(apps, device, simulatorClang,
    { app, host, library, bundle, executable: "PuduObjc", marker: "PUDU_OBJC", expected, link: [] });
  console.log(`${expected}\nPASS iOS Objective-C smoke`);
}

/* A Swift library reached through its C entry points, embedded as a
   framework: an owned object and its release, a callback, and text. */
export function swiftSmoke(apps, device, root, simulatorClang) {
  const { run, xcrun, compiler, identifier } = apps;
  const bundle = `${identifier}.swift`;
  const installName = "@rpath/PuduSwiftCounter.framework/PuduSwiftCounter";
  const directory = join(root, "swift");
  const app = join(directory, "PuduSwift.app");
  const framework = join(app, "Frameworks", "PuduSwiftCounter.framework");
  const swift = join(directory, "Counter.swift");
  const hostLibrary = join(directory, "libPuduSwiftCounter.dylib");
  const source = join(directory, "Main.pudu");
  const library = join(directory, "libSwiftMain.a");
  mkdirSync(framework, { recursive: true });
  writeFileSync(swift, swiftSource);
  run(xcrun, ["swiftc", "-emit-library", "-module-name", "PuduSwiftCounter", swift, "-o", hostLibrary]);
  writeFileSync(source, swiftProgram(hostLibrary, "PUDU_SWIFT"));
  const expected = run(resolve(compiler), ["run", source]).trim();
  assert.equal(expected, swiftExpected.split("\n").map((line) => `PUDU_SWIFT ${line}`).join("\n"));
  writeFileSync(source, swiftProgram(installName, "PUDU_SWIFT"));
  run(resolve(compiler), ["build", source, "--native", "--target", "ios-simulator-arm64", "-o", library]);
  run(xcrun, ["--sdk", "iphonesimulator", "swiftc", "-target", "arm64-apple-ios15.0-simulator",
    "-emit-library", "-module-name", "PuduSwiftCounter", "-Xlinker", "-install_name", "-Xlinker", installName,
    swift, "-o", join(framework, "PuduSwiftCounter")]);
  writeFileSync(join(framework, "Info.plist"), appInfo(`${bundle}.counter`, "PuduSwiftCounter")
    .replace("APPL", "FMWK").replace(/<key>MinimumOSVersion.*\n/u, "").replace(/<key>UIDeviceFamily.*\n/u, ""));
  run("codesign", ["--force", "--sign", "-", framework]);
  installAndCheck(apps, device, simulatorClang, {
    app, host: join(directory, "main.m"), library, bundle, executable: "PuduSwift", marker: "PUDU_SWIFT", expected,
    link: ["-Wl,-rpath,@executable_path/Frameworks"] });
  console.log(`${expected}\nPASS iOS Swift entry points`);
}

function installAndCheck(apps, device, simulatorClang, { app, host, library, bundle, executable, marker, expected, link }) {
  const { run, launch, uninstall, xcrun, simulatorTimeout } = apps;
  mkdirSync(app, { recursive: true });
  writeFileSync(host, hostMain(marker));
  writeFileSync(join(app, "Info.plist"), appInfo(bundle, executable));
  run(xcrun, [...simulatorClang, ...link, host, library, "-framework", "Foundation", "-o", join(app, executable)]);
  run("codesign", ["--force", "--sign", "-", app]);
  try {
    run(xcrun, ["simctl", "install", device, app], simulatorTimeout);
    const lines = launch(device, bundle, marker, `${marker}_STATUS`);
    assert.deepEqual(lines, [...expected.split("\n"), `${marker}_STATUS 0`]);
  } finally {
    uninstall(device, bundle);
  }
}

