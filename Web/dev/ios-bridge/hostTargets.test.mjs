import assert from "node:assert/strict";
import test from "node:test";
import {
  mapTritonHostCapturesToWebTargets,
  mapTritonDeviceListToWebTargets,
  mapTritonSimListToWebTargets,
} from "./hostTargets.mjs";

test("maps triton sim list output into readonly Web iOS targets", () => {
  const result = mapTritonSimListToWebTargets({
    ok: true,
    simulators: [
      {
        id: "sim:AAAA-BBBB",
        udid: "AAAA-BBBB",
        name: "TritonKit Dedicated iPhone 17",
        platform: "iOS Simulator",
        runtime: "iOS 26.5",
        state: "Booted",
        isAvailable: true,
        isBooted: true,
        deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17",
        runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
        source: "simctl",
      },
      {
        id: "sim:CCCC-DDDD",
        udid: "CCCC-DDDD",
        name: "iPad (A16)",
        platform: "iOS Simulator",
        runtime: "iOS 26.5",
        state: "Shutdown",
        isAvailable: true,
        isBooted: false,
        deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPad-A16",
        runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
        source: "simctl",
      },
    ],
  });

  assert.equal(result.ok, true);
  assert.equal(result.source.command, "triton sim list --json");
  assert.equal(result.simulators.length, 1);
  assert.equal(result.simulators[0].id, "sim:AAAA-BBBB");
  assert.equal(result.simulators[0].statusLabel, "Booted");
  assert.equal(result.simulators[0].canScreenshot, true);
});

test("rejects malformed triton sim list output", () => {
  assert.throws(
    () => mapTritonSimListToWebTargets({ ok: true, simulators: "not-an-array" }),
    /simulators/
  );
});

test("maps ready emulator targets and visible real devices for Android and Harmony", () => {
  const result = mapTritonDeviceListToWebTargets(
    {
      ok: true,
      targets: [
        {
          id: "android:emulator-5554",
          target: "emulator-5554",
          name: "Pixel API 35",
          platform: "android",
          appName: "Overloaded",
          packageName: "overloaded.cn.debug",
          ready: true,
          scope: "emulator",
          kind: "emulator",
          state: "device",
          source: "adb",
        },
        {
          id: "android:RF8N",
          target: "RF8N",
          ready: true,
          scope: "real",
          kind: "real-device",
          state: "device",
          transport: "usb",
          blockedReasons: [],
        },
        {
          id: "android:emulator-5556",
          target: "emulator-5556",
          ready: false,
          scope: "emulator",
          kind: "emulator",
          state: "offline",
        },
      ],
    },
    "android"
  );

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "android:emulator-5554");
  assert.equal(result[0].platform, "android");
  assert.equal(result[0].appName, "Overloaded");
  assert.equal(result[0].bundleIdentifier, "overloaded.cn.debug");
  assert.equal(result[0].ready, true);
  assert.equal(result[1].id, "android:RF8N");
  assert.equal(result[1].scope, "real");
  assert.equal(result[1].kind, "real-device");
  assert.equal(result[1].ready, true);
  assert.equal(result[1].transport, "usb");
});

test("filters non-ready real devices from the visible device list", () => {
  const result = mapTritonDeviceListToWebTargets(
    {
      ok: true,
      targets: [
        {
          id: "ios:00008140-redacted",
          target: "00008140-redacted",
          name: "Lin iPhone",
          platform: "ios",
          runtime: "iOS 18.5",
          ready: false,
          scope: "real",
          kind: "real-device",
          state: "device_not_trusted",
          source: "devicectl",
          blockedReasons: ["device_not_trusted"],
        },
      ],
    },
    "ios"
  );

  assert.equal(result.length, 0);
});

test("shows ready iOS localNetwork real devices as App runtime mirror candidates", () => {
  const result = mapTritonDeviceListToWebTargets(
    {
      ok: true,
      targets: [
        {
          id: "ios:wireless",
          target: "ios-real:wireless",
          name: "Wireless iPhone",
          platform: "ios",
          runtime: "iOS 27.0",
          ready: true,
          scope: "real",
          kind: "real-device",
          state: "connected",
          source: "devicectl",
          transport: "localNetwork",
        },
      ],
    },
    "ios"
  );

  assert.equal(result.length, 1);
  assert.equal(result[0].source, "runtime");
  assert.equal(result[0].transport, "localNetwork");
});

test("shows iOS localNetwork real device when an App runtime target is connected", () => {
  const result = mapTritonHostCapturesToWebTargets([
    {
      id: "ios-real-command",
      platform: "ios",
      command: "triton device list --platform ios --scope real --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "ios-real:7a9d976cc4d4",
            target: "ios-real:7a9d976cc4d4",
            name: "iPhone",
            platform: "ios",
            runtime: "iOS 26.5",
            ready: true,
            scope: "real",
            kind: "real-device",
            state: "connected",
            source: "devicectl",
            transport: "localNetwork",
          },
        ],
      },
    },
    {
      id: "runtime-command",
      platform: "runtime",
      command: "triton list --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        targets: [
          {
            id: "triton:connection:7",
            platform: "ios",
            connected: true,
            activeHierarchyAvailable: true,
            transport: "local-websocket",
          },
        ],
      },
    },
  ]);

  assert.equal(result.targets.length, 1);
  assert.equal(result.targets[0].id, "ios-real:7a9d976cc4d4");
  assert.equal(result.targets[0].source, "runtime");
  assert.equal(result.targets[0].transport, "localNetwork");
});

test("hides iOS simulator host targets when App runtime target discovery is unavailable", () => {
  const result = mapTritonHostCapturesToWebTargets([
    {
      id: "ios-command",
      platform: "ios",
      command: "triton sim list --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        simulators: [
          {
            id: "sim:AAAA-BBBB",
            udid: "AAAA-BBBB",
            name: "Overloaded-v2 Dedicated iPhone 16 Pro",
            platform: "iOS Simulator",
            runtime: "iOS 26.5",
            state: "Booted",
            isAvailable: true,
            isBooted: true,
            source: "simctl",
          },
        ],
      },
    },
    {
      id: "runtime-command",
      platform: "runtime",
      command: "triton list --json",
      ok: false,
      exitCode: 1,
      stdout: JSON.stringify({
        ok: false,
        error: {
          code: "server_unavailable",
          message: "Could not connect to the server.",
        },
      }),
      stderr: "",
      parsed: null,
    },
  ]);

  assert.equal(result.ok, true);
  assert.equal(result.targets.length, 0);
  assert.equal(result.commandOutputs.at(-1).ok, false);
});

test("combines iOS, Android, and Harmony host captures for visible target switching", () => {
  const result = mapTritonHostCapturesToWebTargets([
    {
      id: "ios-command",
      platform: "ios",
      command: "triton sim list --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        simulators: [
          {
            id: "sim:AAAA-BBBB",
            udid: "AAAA-BBBB",
            name: "iPhone 15 Pro",
            platform: "iOS Simulator",
            runtime: "iOS 18.5",
            state: "Booted",
            isAvailable: true,
            isBooted: true,
            source: "simctl",
          },
        ],
      },
    },
    {
      id: "runtime-command",
      platform: "runtime",
      command: "triton list --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        targets: [
          {
            id: "triton:connection:14",
            platform: "ios",
            connected: true,
            simulatorUDID: "AAAA-BBBB",
          },
        ],
      },
    },
    {
      id: "ios-real-command",
      platform: "ios",
      command: "triton device list --platform ios --scope real --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "ios:00008140-redacted",
            target: "00008140-redacted",
            name: "Lin iPhone",
            runtime: "iOS 18.5",
            ready: true,
            scope: "real",
            kind: "real-device",
            state: "Ready",
            source: "devicectl",
            transport: "wired",
          },
        ],
      },
    },
    {
      id: "android-command",
      platform: "android",
      command: "triton device list --platform android --scope emulator --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "android:emulator-5554",
            target: "emulator-5554",
            name: "Pixel API 35",
            appName: "Overloaded",
            packageName: "overloaded.cn.debug",
            runtime: "Android 15",
            ready: true,
            scope: "emulator",
            kind: "emulator",
            state: "device",
          },
        ],
      },
    },
    {
      id: "harmony-command",
      platform: "harmony",
      command: "triton device list --platform harmony --scope emulator --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "harmony:127.0.0.1:5555",
            target: "127.0.0.1:5555",
            name: "DevEco Local",
            appName: "Triton Smoke",
            bundleIdentifier: "com.tritonkit.demo",
            runtime: "HarmonyOS NEXT",
            ready: true,
            scope: "emulator",
            kind: "emulator",
            state: "Ready",
          },
        ],
      },
    },
  ]);

  assert.equal(result.ok, true);
  assert.deepEqual(result.source.commands, [
    "triton sim list --json",
    "triton list --json",
    "triton device list --platform ios --scope real --json",
    "triton device list --platform android --scope emulator --json",
    "triton device list --platform harmony --scope emulator --json",
  ]);
  assert.deepEqual(
    result.targets.map((target) => `${target.platform}:${target.name}:${target.bundleIdentifier ?? target.target}`),
    [
      "ios:iPhone 15 Pro:AAAA-BBBB",
      "ios:Lin iPhone:00008140-redacted",
      "android:Pixel API 35:overloaded.cn.debug",
      "harmony:DevEco Local:com.tritonkit.demo",
    ]
  );
});
