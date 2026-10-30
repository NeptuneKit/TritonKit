import { defineReview } from '@linhey/rhine-design/review';
import { makeWorkbenchFixture } from './fixtures';
import type { ReviewScene } from '@linhey/rhine-design/review';
import type { DevicePlatform } from '../src/types';
import { makeSyntheticTargets } from './syntheticData';

const pageScenes: ReviewScene[] = ['device-preview', 'hierarchy-inspector', 'workspace'].map(id => ({
  id, title: id === 'device-preview' ? '设备预览' : id === 'hierarchy-inspector' ? '层级检查' : '分屏工作台', group: '只读工作台',
  source: id === 'device-preview' ? 'Web/src/components/StreamPanel.tsx' : id === 'hierarchy-inspector' ? 'Web/src/components/InspectorPanel.tsx' : 'Web/src/components/WorkspaceCanvas.tsx',
  description: '合成三平台数据；复用实际组件。网络仅由内存协议处理，不连接设备。',
  validation: 'SP-247：页面偏好与深层树验收；树适配关联 Rhine #117。',
  dimensions: [
    { id: 'state', label: '状态', options: (id === 'device-preview' ? ['ready', 'empty', 'image-error', 'long'] : id === 'workspace' ? ['ready', 'empty', 'long'] : ['ready', 'empty', 'loading', 'error', 'long', 'deep', 'copy-error']).map(id => ({id, label: ({ready:'正常',empty:'空结果',loading:'加载中',error:'读取失败',long:'长文本','image-error':'画面失败','copy-error':'复制失败',deep:'深层树'} as Record<string,string>)[id]})) },
    { id: 'platform', label: '平台', options: [{id:'ios',label:'iOS'},{id:'android',label:'Android'},{id:'harmony',label:'Harmony'}] },
    { id: 'role', label: '角色', options: [{id:'reader',label:'只读观察者'}] },
  ],
  async setup(context) {
    const state = context.dimensions.state;
    const platform = context.dimensions.platform as DevicePlatform;
    const targets = makeSyntheticTargets(state).sort((a,b) => Number(b.platform === platform) - Number(a.platform === platform));
    context.mockHttp(request => {
      if (request.method !== 'GET' || new URL(request.url).pathname !== '/web/target-registry') return undefined;
      return Response.json({ok:true,targets:targets.map(target => ({id:target.id,platform:target.platform,kind:target.kind,host:{target:target.targetSelector,name:target.name,runtime:target.os,scope:target.scope,kind:target.kind,source:'synthetic',state:'ready',ready:true},mirror:{state:'ready'}}))});
    });
    const copyText = async () => { context.signal.throwIfAborted(); if (state === 'copy-error') throw new Error('合成复制失败，请重试'); context.report('合成内容已复制（仅内存反馈）'); };
    if (id === 'device-preview') {
      const {StreamScene} = await import('./StreamScene'); context.signal.throwIfAborted();
      return {render: () => <StreamScene platform={platform} state={state} />,dispose() {}};
    }
    if (id === 'hierarchy-inspector') {
      const {InspectorScene} = await import('./InspectorScene'); context.signal.throwIfAborted();
      return {render: () => <InspectorScene platform={platform} state={state} copyText={copyText} />,dispose() {}};
    }
    const {WorkspaceScene} = await import('./WorkspaceScene'); context.signal.throwIfAborted();
    return {render: () => <WorkspaceScene platform={platform} state={state} copyText={copyText} />,dispose() {}};
  },
}));

export default defineReview({
  title: 'TritonKit · 只读工作台设计评审',
  widths: [400, 520, 880, 1280],
  scenes: [{
    id: 'run-atlas', title: 'Run / Atlas Workbench', group: '只读工作台',
    source: 'Web/src/components/RunWorkbenchView.tsx',
    description: '合成数据；概览、路径与命令复用实际组件。所有业务动作由 CLI/HTTP 执行。',
    validation: '验收记录见 SP-247；主题、尺寸和页签保持同一组件实例。',
    dimensions: [
      { id: 'state', label: '状态', options: [
        { id: 'ready', label: '正常' }, { id: 'failed', label: '运行失败' },
        { id: 'empty', label: '空结果' }, { id: 'loading', label: '加载中' },
        { id: 'error', label: '读取错误' }, { id: 'long', label: '长文本' },
      ] },
      { id: 'role', label: '角色', options: [{ id: 'reader', label: '只读观察者' }] },
    ],
    async setup(context) {
      context.mockHttp(() => undefined);
      const { RunWorkbenchView } = await import('../src/components/RunWorkbenchView');
      context.signal.throwIfAborted();
      const state = context.dimensions.state;
      const workbench = makeWorkbenchFixture(state);
      return {
        render: () => <RunWorkbenchView workbench={workbench} state={state === 'loading' || state === 'error' ? state : 'ready'} copyCommand={async () => { context.signal.throwIfAborted(); context.report('合成命令已复制（仅内存反馈）'); }} />,
        dispose() {},
      };
    },
  }, ...pageScenes],
});
