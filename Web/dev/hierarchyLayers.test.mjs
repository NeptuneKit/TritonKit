import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { createServer } from 'vite';
const server = await createServer({configFile:false,appType:'custom',esbuild:{jsx:'automatic'},
  server:{middlewareMode:true,hmr:false,ws:false},optimizeDeps:{noDiscovery:true},ssr:{noExternal:['@linhey/rhine-design']}});
after(() => server.close());
const {makeLayerPlanes,layerCameraKey,dragLayerCamera,INITIAL_LAYER_CAMERA,MAX_LAYER_PLANES} = await server.ssrLoadModule('/src/inspect/layerPlanes.ts');
const {HierarchyLayers} = await server.ssrLoadModule('/src/components/HierarchyLayers.tsx');
const {makeLayerScene} = await server.ssrLoadModule('/design/LayerScene.tsx');
const render = (scene,selectedNodeId) => renderToStaticMarkup(createElement(HierarchyLayers,{scene,selectedNodeId,onSelect(){},onHover(){}}));

test('planes use solo materials and never subtree screenshots', () => {
  const scene = makeLayerScene();
  const result = makeLayerPlanes(scene);
  assert.equal(result.missingImages,0);
  assert.ok(result.planes.every(plane => !decodeURIComponent(plane.image).includes('GROUP')));
  const html = render(scene,'child-action');
  assert.match(html,/aria-label="3D 分层视图"/);
  assert.match(html,/aria-label="旋转图层画布"/);
  assert.match(html,/data-layer-node="child-action"[^>]*aria-pressed="true"/);
  assert.match(html,/层间距/); assert.match(html,/重置视角/);
  assert.doesNotMatch(html,/GROUP|执行|应用到设备/);
});
test('missing images and empty snapshots remain honest', () => {
  assert.match(render(makeLayerScene('ios','missing-images')),/4 层无独立截图/);
  assert.match(render(makeLayerScene('ios','empty')),/无可显示的图层/);
  const scene = makeLayerScene();
  scene.nodes.forEach(node => { node.visualSources = node.visualSources.filter(source => source.kind === 'subtreeSnapshot'); });
  assert.equal(makeLayerPlanes(scene).missingImages,4);
});
test('invalid geometry, hidden ancestors and cycles are excluded without recursion loops', () => {
  const scene = makeLayerScene();
  scene.nodes[1].visible = false;
  assert.deepEqual(makeLayerPlanes(scene).planes.map(p=>p.node.id),['root','child-action']);
  scene.nodes[0].parentId='child-action'; scene.nodes[3].parentId='root';
  assert.equal(makeLayerPlanes(scene).planes.length,0);
  const invalid = makeLayerScene(); invalid.nodes[1].frame.width=NaN;
  assert.ok(!makeLayerPlanes(invalid).planes.some(p=>p.node.id==='child-container'));
});
test('large snapshots are bounded while preserving selected node', () => {
  const scene = makeLayerScene();
  scene.nodes=Array.from({length:400},(_,i)=>({...scene.nodes[0],id:`node-${i}`,depth:i}));
  const result=makeLayerPlanes(scene,'node-399');
  assert.equal(result.planes.length,MAX_LAYER_PLANES); assert.equal(result.omitted,200);
  assert.ok(result.planes.some(p=>p.node.id==='node-399')); assert.ok(result.planes.every(p=>p.depth<=64));
});
test('camera keyboard has bounded rotation and Home resets without hijacking Tab', () => {
  assert.equal(layerCameraKey(INITIAL_LAYER_CAMERA,'Tab'),null);
  assert.equal(layerCameraKey({x:65,y:75},'ArrowRight').y,75);
  assert.deepEqual(layerCameraKey({x:65,y:75},'Home'),INITIAL_LAYER_CAMERA);
});
test('pointer rotation normalizes by rendered size at 200 percent zoom', () => {
  assert.deepEqual(dragLayerCamera(INITIAL_LAYER_CAMERA,10,20,400,800),dragLayerCamera(INITIAL_LAYER_CAMERA,20,40,800,1600));
  assert.deepEqual(dragLayerCamera(INITIAL_LAYER_CAMERA,0,0,400,800),INITIAL_LAYER_CAMERA);
});

test('node evidence labels solo and group separately without claiming missing images exist', async () => {
  const {NodeImageEvidence} = await server.ssrLoadModule('/src/components/NodeImageEvidence.tsx');
  const html=renderToStaticMarkup(createElement(NodeImageEvidence,{node:makeLayerScene().nodes[1]}));
  assert.match(html,/仅此图层/); assert.match(html,/包含子图层/); assert.equal((html.match(/<img /g)||[]).length,2);
  const empty=renderToStaticMarkup(createElement(NodeImageEvidence,{node:makeLayerScene('ios','missing-images').nodes[1]}));
  assert.equal((empty.match(/当前快照未提供/g)||[]).length,2); assert.doesNotMatch(empty,/<img /);
});

test('zero-sized structural ancestors do not erase visible descendants, explicit hidden ancestors do', () => {
  const scene=makeLayerScene();
  const parent=scene.nodes[1]; parent.frame={x:0,y:0,width:0,height:0}; parent.visible=false;
  assert.ok(makeLayerPlanes(scene).planes.some(p=>p.node.id==='child-title'));
  parent.view={...parent.view,isHidden:true};
  assert.ok(!makeLayerPlanes(scene).planes.some(p=>p.node.id==='child-title'));
  parent.view={...parent.view,isHidden:false,alpha:0}; parent.layer={isHidden:false,opacity:1};
  assert.ok(!makeLayerPlanes(scene).planes.some(p=>p.node.id==='child-title'));
});
