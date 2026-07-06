import assert from "node:assert/strict";
import test from "node:test";
import { createIosSimulatorBridgeMiddleware } from "./index.mjs";
import {
  createFakeRuntimeDataServer,
  createFakeTritonScript,
  createFakeTritonScriptFromSource,
  invokeMiddleware,
  pngBytes,
} from "./testSupport.mjs";

test("serves readonly Lookin-style hierarchy scenes for iOS Android and Harmony host targets", async () => {
  const cases = [
    ["ios", "AAAA-BBBB", "UIStackView", "questionList"],
    ["android", "emulator-5554", "AndroidComposeView", "settingsList"],
    ["harmony", "127.0.0.1:5555", "ArkUIRoot", "settingsContent"],
  ];

  for (const [platform, target, type, name] of cases) {
    const tritonPath = await createFakeTritonScript({
      stdout: JSON.stringify({
        ok: true,
        capturedAt: "2026-06-19T00:00:00.000Z",
        source: {
          command: `triton debug hierarchy --platform ${platform} --target ${target} --json`,
          runtimeScope: platform === "ios" ? "runtime-tree" : "host-layout",
          readonly: true,
        },
        scene: {
          platform,
          rootId: "root",
          viewport: { width: 390, height: 844 },
          nodes: [
            {
              id: "root",
              type: "RootView",
              name: "root",
              frame: { x: 0, y: 0, width: 390, height: 844 },
              depth: 0,
              visible: true,
              interactive: false,
              color: "#6ea8ff",
            },
            {
              id: "child",
              parentId: "root",
              type,
              name,
              frame: { x: 24, y: 120, width: 342, height: 56 },
              depth: 1,
              visible: true,
              interactive: true,
              color: "#fb7185",
            },
          ],
        },
      }),
      outputTemplate: "unused",
    });
    const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
    const response = await invokeMiddleware(middleware, {
      method: "GET",
      url: `/web/host-hierarchy?platform=${platform}&target=${encodeURIComponent(target)}`,
    });

    assert.equal(response.statusCode, 200);
    assert.match(response.headers["content-type"], /application\/json/);

    const body = JSON.parse(response.body);
    assert.equal(body.ok, true);
    assert.equal(body.source.command, `triton debug hierarchy --platform ${platform} --target ${target} --json`);
    assert.equal(body.source.runtimeScope, platform === "ios" ? "runtime-tree" : "host-layout");
    assert.equal(body.source.readonly, true);
    assert.equal(body.scene.platform, platform);
    assert.ok(body.scene.viewport.width > 0);
    assert.ok(body.scene.viewport.height > 0);
    assert.ok(body.scene.nodes.some((node) => node.type === type));
    assert.ok(body.scene.nodes.some((node) => node.name === name));
  }
});

test("resolves bare iOS real-device hierarchy target through App runtime mirror", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:connection:42",
        platform: "ios",
        connected: true,
        deviceDescription: "iPhone",
        transport: "local-websocket"
      },
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        deviceDescription: "Simulator",
        transport: "local-websocket"
      }
    ]
  }));
  process.exit(0);
}
if (args.join(" ") !== "debug hierarchy --platform ios --target triton:connection:42 --json") {
  process.stderr.write("unexpected args: " + args.join(" "));
  process.exit(64);
}
process.stdout.write(JSON.stringify({
  ok: true,
  capturedAt: "2026-06-19T00:00:00.000Z",
  source: {
    command: "triton debug hierarchy --platform ios --target triton:connection:42 --json",
    runtimeScope: "runtime-tree",
    readonly: true
  },
  scene: {
    platform: "ios",
    rootId: "root",
    viewport: { width: 428, height: 926 },
    nodes: [
      {
        id: "root",
        type: "UIWindow",
        name: "keyWindow",
        frame: { x: 0, y: 0, width: 428, height: 926 },
        depth: 0,
        visible: true,
        interactive: false,
        color: "#6ea8ff"
      }
    ]
  }
}));
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-hierarchy?platform=ios&target=ios-real%3A7a9d976cc4d4",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --platform ios --target triton:connection:42 --json");
  assert.equal(body.scene.viewport.width, 428);
});

test("rejects iOS real-device hierarchy when only simulator runtime is connected", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        activeHierarchyAvailable: true,
        appName: "Overloaded",
        bundleIdentifier: "overloaded.cn.debug",
        transport: "local-websocket"
      }
    ]
  }));
  process.exit(0);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(64);
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-hierarchy?platform=ios&target=ios-real%3A7a9d976cc4d4&scope=real&kind=real-device&source=runtime",
  });

  assert.equal(response.statusCode, 409);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, false);
  assert.equal(body.error.code, "app_runtime_unavailable");
  assert.match(body.error.message, /No connected iOS real-device App runtime target matched host target ios-real:7a9d976cc4d4/);
  assert.match(body.error.message, /triton:ios-simulator:SIM-UDID/);
});

test("exposes explicit Web hierarchy capture control through POST without mutating the app", async () => {
  const tritonPath = await createFakeTritonScript({
    stdout: JSON.stringify({
      ok: true,
      capturedAt: "2026-06-19T00:00:00.000Z",
      source: {
        command: "triton debug hierarchy --platform ios --target AAAA-BBBB --json",
        runtimeScope: "runtime-tree",
        readonly: true,
      },
      scene: {
        platform: "ios",
        rootId: "root",
        viewport: { width: 390, height: 844 },
        nodes: [
          {
            id: "root",
            type: "UIWindow",
            name: "keyWindow",
            frame: { x: 0, y: 0, width: 390, height: 844 },
            depth: 0,
            visible: true,
            interactive: false,
            color: "#6ea8ff",
          },
        ],
      },
    }),
    outputTemplate: "unused",
  });
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.deepEqual(body.control, {
    action: "hierarchy.capture",
    entrypoint: "web-dev-bridge",
    method: "POST",
    readonly: true,
    mutatesApp: false,
  });
  assert.equal(body.source.command, "triton debug hierarchy --platform ios --target AAAA-BBBB --json");
});

test("hydrates platform hierarchy scene dataRef slices into data URLs", async () => {
  const nodePng = pngBytes(10, 6);
  const dataServer = await createFakeRuntimeDataServer({
    "22222222-2222-2222-2222-222222222222": nodePng,
  });
  try {
    const tritonPath = await createFakeTritonScript({
      stdout: JSON.stringify({
        ok: true,
        capturedAt: "2026-06-19T01:00:00Z",
        source: {
          command: "triton debug hierarchy --platform ios --target AAAA-BBBB --json",
          runtimeScope: "runtime-tree",
          readonly: true,
        },
        scene: {
          platform: "ios",
          rootId: "root",
          viewport: { width: 390, height: 844 },
          nodes: [
            {
              id: "root",
              type: "UIWindow",
              name: "keyWindow",
              frame: { x: 0, y: 0, width: 390, height: 844 },
              depth: 0,
              visible: true,
              interactive: false,
              color: "#6ea8ff",
            },
            {
              id: "button",
              parentId: "root",
              type: "UIButton",
              name: "Continue",
              frame: { x: 24, y: 132, width: 342, height: 58 },
              depth: 1,
              visible: true,
              interactive: true,
              color: "#2563eb",
              slice: {
                available: true,
                mode: "node-screenshot-ref",
                source: "triton-runtime-data-ref",
                dataRef: "22222222-2222-2222-2222-222222222222",
              },
              renderHints: {
                preferredMode: "slice",
                fallbackMode: "style",
                quality: "exact",
              },
            },
          ],
        },
      }),
      outputTemplate: "unused",
    });
    const middleware = createIosSimulatorBridgeMiddleware({
      tritonPath,
      runtimeDataBaseURL: dataServer.baseURL,
    });
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
    });

    assert.equal(response.statusCode, 200);
    const body = JSON.parse(response.body);
    const button = body.scene.nodes.find((node) => node.id === "button");
    assert.equal(button.slice.dataRef, "22222222-2222-2222-2222-222222222222");
    assert.equal(button.slice.dataUrl, `data:image/png;base64,${nodePng.toString("base64")}`);
    assert.equal(button.visualSources[0].kind, "subtreeSnapshot");
    assert.equal(button.visualSources[0].dataRef, "22222222-2222-2222-2222-222222222222");
    assert.equal(button.visualSources[0].dataUrl, `data:image/png;base64,${nodePng.toString("base64")}`);
    assert.equal(button.visualSources[0].capturedBy, "UIView.render");
    assert.equal(button.renderHints.preferredMode, "slice");
    assert.equal(button.renderHints.quality, "exact");
    assert.equal(body.captureEvidence.source.kind, "triton-hierarchy");
    assert.equal(body.captureEvidence.source.nodeSlice, "real");
    assert.equal(body.captureEvidence.source.screenshotSlice, "real");
    assert.equal(body.captureEvidence.hydration.dataUrlCount, 1);
    assert.equal(body.captureEvidence.hydration.nodeCount, 2);
    assert.equal(body.captureEvidence.hydration.failedNodeCount, 0);
  } finally {
    await dataServer.close();
  }
});

test("falls back to legacy iOS runtime hierarchy and converts it to a Web scene when platform scene schema is unavailable", async () => {
  const legacyPayload = {
    appInfo: {
      appName: "Overloaded",
      screenWidth: 402,
      screenHeight: 874,
    },
    displayItems: [
      {
        indentLevel: 0,
        frame: [[0, 0], [402, 874]],
        alpha: 1,
        isHidden: false,
        backgroundColor: { red: 1, green: 1, blue: 1, alpha: 1 },
        layerObject: { oid: 2, classChainList: ["UIWindow", "UIView"] },
        subitems: [
          {
            indentLevel: 1,
            frame: [[0, 106], [402, 685]],
            alpha: 1,
            isHidden: false,
            backgroundColor: { red: 0.96, green: 0.96, blue: 0.96, alpha: 1 },
            layerObject: { oid: 26, classChainList: ["SectionUI.SKCollectionView", "UICollectionView"] },
            hostViewControllerObject: { oid: 88, classChainList: ["Demo.ProfileViewController", "UIViewController"] },
            subitems: [
              {
                indentLevel: 2,
                frame: [[24, 132], [342, 58]],
                alpha: 1,
                isHidden: false,
                layerObject: { oid: 38, classChainList: ["UILabel", "UIView"] },
                subitems: [],
              },
            ],
          },
        ],
      },
    ],
  };
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
if (process.argv.includes("--platform")) {
  process.stderr.write("Error: Unknown option '--platform'\\n");
  process.exit(64);
}
process.stdout.write(${JSON.stringify(JSON.stringify(legacyPayload))});
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --target AAAA-BBBB --json");
  assert.equal(body.source.runtimeScope, "runtime-tree");
  assert.equal(body.scene.platform, "ios");
  assert.equal(body.scene.viewport.width, 402);
  assert.equal(body.scene.viewport.height, 874);
  const controller = body.scene.nodes.find((node) => node.id === "ios:controller:88");
  assert.ok(controller);
  assert.equal(controller.type, "Demo.ProfileViewController");
  assert.equal(controller.name, "ProfileViewController#88");
  assert.equal(controller.raw.role, "UIViewController");
  assert.equal(controller.renderHints.preferredMode, "structure");
  const collection = body.scene.nodes.find((node) => node.type === "SectionUI.SKCollectionView");
  assert.equal(collection.parentId, controller.id);
  assert.equal(body.scene.controllerContext.activeControllerId, "ios:controller:88");
  assert.equal(body.scene.controllerContext.activeControllerName, "ProfileViewController");
  assert.equal(body.scene.controllerContext.source, "scene-controller-node-fallback");
  assert.ok(body.scene.nodes.some((node) => node.type === "SectionUI.SKCollectionView"));
  assert.ok(body.scene.nodes.some((node) => node.type === "UILabel" && node.renderHints.preferredMode === "slice"));
});

test("falls back to legacy iOS runtime hierarchy when scene mode cannot resolve a simulator UDID target", async () => {
  const legacyPayload = {
    appInfo: { screenWidth: 402, screenHeight: 874 },
    displayItems: [
      {
        indentLevel: 0,
        frame: [[0, 0], [402, 874]],
        alpha: 1,
        isHidden: false,
        layerObject: { oid: 2, classChainList: ["UIWindow", "UIView"] },
        subitems: [
          {
            indentLevel: 1,
            frame: [[24, 132], [342, 58]],
            alpha: 1,
            isHidden: false,
            layerObject: { oid: 38, classChainList: ["UILabel", "UIView"] },
            subitems: [],
          },
        ],
      },
    ],
  };
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
if (process.argv.includes("--platform")) {
  process.stdout.write(JSON.stringify({ ok: false, error: { code: "target_not_found", message: "Target not found: AAAA-BBBB" } }));
  process.exit(1);
}
process.stdout.write(${JSON.stringify(JSON.stringify(legacyPayload))});
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --target AAAA-BBBB --json");
  assert.ok(body.scene.nodes.some((node) => node.type === "UILabel"));
});

test("falls back to a matching iOS simulator runtime target when simulator UDID scene lookup fails", async () => {
  const legacyPayload = {
    appInfo: { screenWidth: 402, screenHeight: 874 },
    displayItems: [
      {
        indentLevel: 0,
        frame: [[0, 0], [402, 874]],
        alpha: 1,
        isHidden: false,
        layerObject: { oid: 2, classChainList: ["UIWindow", "UIView"] },
        subitems: [],
      },
    ],
  };
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({ targets: [{ id: "triton:local", platform: "ios", connected: true, simulatorUDID: "AAAA-BBBB" }] }));
  process.exit(0);
}
if (args.includes("--platform")) {
  process.stdout.write(JSON.stringify({ ok: false, error: { code: "target_not_found", message: "Target not found: AAAA-BBBB" } }));
  process.exit(1);
}
if (args.includes("--target") && args[args.indexOf("--target") + 1] === "triton:local") {
  process.stdout.write(${JSON.stringify(JSON.stringify(legacyPayload))});
  process.exit(0);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(2);
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --target triton:local --json");
  assert.equal(body.scene.rootId, "ios:runtime:2");
});

test("does not map a simulator host target to an unrelated iOS runtime fallback", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({ targets: [{ id: "triton:connection:3", platform: "ios", connected: true }] }));
  process.exit(0);
}
if (args.includes("--platform")) {
  process.stdout.write(JSON.stringify({ ok: false, error: { code: "target_not_found", message: "Target not found: AAAA-BBBB" } }));
  process.exit(1);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(2);
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB&scope=simulator&kind=simulator",
  });

  assert.equal(response.statusCode, 409);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, false);
  assert.equal(body.error.code, "web_host_hierarchy_failed");
  assert.match(body.error.message, /No connected iOS App runtime target matched host target AAAA-BBBB/);
});

test("hydrates legacy iOS screenshotRef into hierarchy node slice data URLs", async () => {
  const nodePng = pngBytes(12, 8);
  const dataServer = await createFakeRuntimeDataServer({
    "11111111-1111-1111-1111-111111111111": nodePng,
  });
  try {
    const legacyPayload = {
      appInfo: { screenWidth: 402, screenHeight: 874 },
      displayItems: [
        {
          indentLevel: 0,
          frame: [[0, 0], [402, 874]],
          alpha: 1,
          isHidden: false,
          layerObject: { oid: 2, classChainList: ["UIWindow", "UIView"] },
          subitems: [
            {
              indentLevel: 1,
              frame: [[24, 132], [342, 58]],
              alpha: 1,
              isHidden: false,
              customDisplayTitle: "Continue",
              screenshotRef: "11111111-1111-1111-1111-111111111111",
              backgroundColor: { red: 0.1, green: 0.2, blue: 0.3, alpha: 1 },
              layerObject: { oid: 38, classChainList: ["UIButtonLabel", "UILabel", "UIView"] },
              subitems: [],
            },
          ],
        },
      ],
    };
    const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
if (process.argv.includes("--platform")) {
  process.stderr.write("Error: Unknown option '--platform'\\n");
  process.exit(64);
}
process.stdout.write(${JSON.stringify(JSON.stringify(legacyPayload))});
`);
    const middleware = createIosSimulatorBridgeMiddleware({
      tritonPath,
      runtimeDataBaseURL: dataServer.baseURL,
    });
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
    });

    assert.equal(response.statusCode, 200);
    const body = JSON.parse(response.body);
    const button = body.scene.nodes.find((node) => node.type === "UIButtonLabel");
    assert.ok(button);
    assert.equal(button.name, "Continue");
    assert.equal(button.style.text, "Continue");
    assert.deepEqual(button.slice, {
      available: true,
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
      dataRef: "11111111-1111-1111-1111-111111111111",
      dataUrl: `data:image/png;base64,${nodePng.toString("base64")}`,
    });
    assert.equal(button.visualSources[0].kind, "subtreeSnapshot");
    assert.equal(button.visualSources[0].dataRef, "11111111-1111-1111-1111-111111111111");
    assert.equal(button.visualSources[0].dataUrl, `data:image/png;base64,${nodePng.toString("base64")}`);
    assert.equal(button.visualSources[0].capturedBy, "UIView.render");
    assert.equal(button.renderHints.preferredMode, "slice");
    assert.equal(button.renderHints.quality, "exact");
  } finally {
    await dataServer.close();
  }
});

test("rejects unsupported /web/host-hierarchy platform with readonly unsupported envelope", async () => {
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath: process.execPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-hierarchy?platform=webos&target=local",
  });

  assert.equal(response.statusCode, 501);
  assert.match(response.headers["content-type"], /application\/json/);
  assert.deepEqual(JSON.parse(response.body), {
    ok: false,
    error: {
      code: "web_host_hierarchy_platform_not_supported",
      message: "Readonly host hierarchy is not available for platform: webos",
    },
  });
});
