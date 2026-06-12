import assert from "node:assert/strict";
import test from "node:test";
import {
  mapTritonDeviceListToWebTargets,
  mapTritonSimListToWebTargets,
  normalizeIosRuntimeInput,
} from "./iosSimulatorBridge.mjs";

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

test("maps only ready emulator targets for Android and Harmony", () => {
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

  assert.equal(result.length, 1);
  assert.equal(result[0].id, "android:emulator-5554");
  assert.equal(result[0].platform, "android");
  assert.equal(result[0].appName, "Overloaded");
  assert.equal(result[0].bundleIdentifier, "overloaded.cn.debug");
  assert.equal(result[0].ready, true);
});

test("normalizes iOS framebuffer coordinates into runtime point coordinates", () => {
  const normalized = normalizeIosRuntimeInput(
    {
      action: "tap",
      platform: "ios",
      target: "60667794-96F8-40E6-8664-85538EC4663E",
      x: 619,
      y: 2338,
      width: 1206,
      height: 2622,
    },
    {
      screenWidth: 402,
      screenHeight: 874,
      screenScale: 3,
    }
  );

  assert.equal(normalized.x, 206);
  assert.equal(normalized.y, 779);
  assert.equal(normalized.width, 402);
  assert.equal(normalized.height, 874);
});
