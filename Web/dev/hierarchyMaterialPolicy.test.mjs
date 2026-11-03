import assert from "node:assert/strict";
import { after, test } from "node:test";
import { createServer } from "vite";

const viteServer = await createServer({
  configFile: false,
  optimizeDeps: { noDiscovery: true },
  appType: "custom",
  server: {
    hmr: false,
    middlewareMode: true,
    ws: false,
  },
});

const {
  computeParityClaim,
  effectiveVisualSources,
  getMaterialExplanation,
  resolveDefaultMaterialSource,
  resolveEvidenceSources,
} = await viteServer.ssrLoadModule("/src/data/hierarchyMaterialPolicy.ts");

after(async () => {
  await viteServer.close();
});

test("subtreeSnapshot is never default material", () => {
  const node = {
    id: "button",
    type: "UIButton",
    name: "button",
    frame: { x: 0, y: 0, width: 100, height: 44 },
    depth: 1,
    visible: true,
    interactive: true,
    color: "#2563eb",
    visualSources: [
      {
        kind: "subtreeSnapshot",
        dataUrl: "data:image/png;base64,AAA=",
        rect: { x: 0, y: 0, width: 100, height: 44 },
        capturedBy: "UIView.render",
      },
    ],
  };

  assert.equal(resolveDefaultMaterialSource(node), null);
});

test("layerOwnContents is the only default material", () => {
  const node = {
    id: "imageView",
    type: "UIImageView",
    name: "imageView",
    frame: { x: 0, y: 0, width: 80, height: 80 },
    depth: 1,
    visible: true,
    interactive: false,
    color: "#94a3b8",
    visualSources: [
      {
        kind: "subtreeSnapshot",
        dataUrl: "data:image/png;base64,AAA=",
        rect: { x: 0, y: 0, width: 80, height: 80 },
        capturedBy: "UIView.render",
      },
      {
        kind: "layerOwnContents",
        dataUrl: "data:image/png;base64,BBB=",
        rect: { x: 0, y: 0, width: 80, height: 80 },
        capturedBy: "CALayer.contents",
      },
    ],
  };

  const source = resolveDefaultMaterialSource(node);
  assert.ok(source);
  assert.equal(source.kind, "layerOwnContents");
});

test("legacy slice bridges to subtreeSnapshot evidence", () => {
  const node = {
    id: "label",
    type: "UILabel",
    name: "label",
    frame: { x: 0, y: 0, width: 200, height: 30 },
    depth: 1,
    visible: true,
    interactive: false,
    color: "#64748b",
    slice: {
      available: true,
      dataUrl: "data:image/png;base64,CCC=",
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
    },
  };

  const sources = effectiveVisualSources(node);
  assert.equal(sources.length, 1);
  assert.equal(sources[0].kind, "subtreeSnapshot");
  assert.equal(sources[0].dataUrl, "data:image/png;base64,CCC=");
});

test("empty visualSources and no slice produces empty evidence", () => {
  const node = {
    id: "plain",
    type: "UIView",
    name: "plain",
    frame: { x: 0, y: 0, width: 100, height: 100 },
    depth: 1,
    visible: true,
    interactive: false,
    color: "#94a3b8",
    slice: { available: false },
  };

  const sources = effectiveVisualSources(node);
  assert.deepEqual(sources, []);
});

test("computeParityClaim returns snapshotEvidenceViewer for subtreeSnapshot-only scene", () => {
  const scene = {
    platform: "ios",
    rootId: "root",
    viewport: { width: 390, height: 844 },
    nodes: [
      {
        id: "root",
        type: "UIWindow",
        name: "root",
        frame: { x: 0, y: 0, width: 390, height: 844 },
        depth: 0,
        visible: true,
        interactive: false,
        color: "#94a3b8",
      },
      {
        id: "child1",
        parentId: "root",
        type: "UIView",
        name: "child1",
        frame: { x: 0, y: 0, width: 200, height: 100 },
        depth: 1,
        visible: true,
        interactive: false,
        color: "#64748b",
        visualSources: [
          {
            kind: "subtreeSnapshot",
            dataUrl: "data:image/png;base64,AAA=",
            rect: { x: 0, y: 0, width: 200, height: 100 },
            capturedBy: "UIView.render",
          },
        ],
      },
      {
        id: "child2",
        parentId: "root",
        type: "UILabel",
        name: "child2",
        frame: { x: 0, y: 100, width: 200, height: 30 },
        depth: 1,
        visible: true,
        interactive: false,
        color: "#94a3b8",
        visualSources: [
          {
            kind: "subtreeSnapshot",
            dataUrl: "data:image/png;base64,BBB=",
            rect: { x: 0, y: 100, width: 200, height: 30 },
            capturedBy: "UIView.render",
          },
        ],
      },
    ],
  };

  const claim = computeParityClaim(scene);
  assert.equal(claim.canClaimLookinParity, false);
  assert.equal(claim.level, "snapshotEvidenceViewer");
  assert.ok(claim.reasons.length > 0);
});

test("computeParityClaim returns snapshotEvidenceViewer for empty scene", () => {
  const scene = {
    platform: "ios",
    rootId: "root",
    viewport: { width: 390, height: 844 },
    nodes: [],
  };

  const claim = computeParityClaim(scene);
  assert.equal(claim.canClaimLookinParity, false);
  assert.equal(claim.level, "snapshotEvidenceViewer");
});

test("getMaterialExplanation reports correct reason for missing layerOwnContents", () => {
  const node = {
    id: "button",
    type: "UIButton",
    name: "button",
    frame: { x: 0, y: 0, width: 100, height: 44 },
    depth: 1,
    visible: true,
    interactive: true,
    color: "#2563eb",
    visualSources: [
      {
        kind: "subtreeSnapshot",
        dataUrl: "data:image/png;base64,AAA=",
        rect: { x: 0, y: 0, width: 100, height: 44 },
        capturedBy: "UIView.render",
      },
    ],
  };

  const explanation = getMaterialExplanation(node);
  assert.equal(explanation.defaultMaterial, null);
  assert.ok(explanation.reason.includes("No layerOwnContents"));
  assert.deepEqual(explanation.evidenceSources, ["subtreeSnapshot"]);
});

test("resolveEvidenceSources returns all sources including legacy bridge", () => {
  const node = {
    id: "mixed",
    type: "UIView",
    name: "mixed",
    frame: { x: 0, y: 0, width: 100, height: 100 },
    depth: 1,
    visible: true,
    interactive: false,
    color: "#94a3b8",
    visualSources: [
      {
        kind: "styledFallback",
        rect: { x: 0, y: 0, width: 100, height: 100 },
        reason: "No layer contents available",
      },
    ],
    slice: {
      available: true,
      dataUrl: "data:image/png;base64,DDD=",
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
    },
  };

  const sources = resolveEvidenceSources(node);
  assert.equal(sources.length, 2);
  assert.equal(sources[0].kind, "styledFallback");
  assert.equal(sources[1].kind, "subtreeSnapshot");
});

test('solo slice retains layer-own semantics and duplicate image refs are not repeated', () => {
  const node = { id: 'solo', frame: {x:0,y:0,width:50,height:50}, slice: {
    available: true, mode: 'solo-screenshot-ref', dataRef: 'solo-ref', dataUrl: 'data:image/png;base64,AAA=' },
    visualSources: [{kind:'layerOwnContents',dataRef:'solo-ref',dataUrl:'data:image/png;base64,AAA=',rect:{x:0,y:0,width:50,height:50}}] };
  assert.equal(effectiveVisualSources(node).length, 1);
  assert.equal(resolveDefaultMaterialSource({...node,visualSources:[]})?.kind, 'layerOwnContents');
});
test('an unresolved dataRef is not proof of a displayable plane image', () => {
  const node = { id:'unresolved', frame:{x:0,y:0,width:50,height:50}, visualSources:[
    {kind:'layerOwnContents',dataRef:'not-hydrated',rect:{x:0,y:0,width:50,height:50}}] };
  assert.equal(resolveDefaultMaterialSource(node), null);
});

test('inline solo remains own contents and inline group stays evidence without duplicate sources', () => {
  const frame = {x:0,y:0,width:50,height:50};
  const dataUrl = 'data:image/png;base64,AAA=';
  const solo = {id:'inline',frame,slice:{available:true,mode:'solo-screenshot-inline',source:'triton-runtime-inline-png',dataUrl}};
  assert.equal(resolveDefaultMaterialSource(solo)?.dataUrl, dataUrl);
  assert.deepEqual(effectiveVisualSources({...solo,visualSources:[{kind:'layerOwnContents',rect:frame,dataUrl}]}).map(s=>s.kind), ['layerOwnContents']);
  const group = {...solo,slice:{...solo.slice,mode:'group-screenshot-inline'}};
  assert.equal(resolveDefaultMaterialSource(group), null);
  assert.deepEqual(effectiveVisualSources(group).map(s=>s.kind), ['subtreeSnapshot']);
});

test('supplementary group evidence does not contradict an available solo material', () => {
  const node={id:'both',depth:1,visible:true,frame:{x:0,y:0,width:1,height:1},visualSources:[
    {kind:'layerOwnContents',dataUrl:'data:image/png;base64,AAA=',rect:{x:0,y:0,width:1,height:1}},
    {kind:'subtreeSnapshot',dataUrl:'data:image/png;base64,BBB=',rect:{x:0,y:0,width:1,height:1},capturedBy:'CALayer.render'}]};
  const claim=computeParityClaim({nodes:[node]});
  assert.equal(claim.level,'layerOwnContents'); assert.deepEqual(claim.reasons,[]);
});
