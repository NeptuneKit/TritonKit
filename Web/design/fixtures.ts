import type { WorkspaceWorkbenchDTO } from '../src/types';

export function makeWorkbenchFixture(state: string): WorkspaceWorkbenchDTO {
  const fixture: WorkspaceWorkbenchDTO = {
    run: {
      runId: 'synthetic-run-001', status: 'paused', goal: '从欢迎页进入合成工作区',
      app: { name: '示例应用', bundleId: 'org.example.synthetic' },
      target: { platform: 'ios', scope: 'simulator', name: '合成目标', targetSelector: 'synthetic-target' },
      llmEnabled: true, vlmEnabled: false, providersReady: false,
      latestPause: { reason: '等待操作者检查证据', evidenceRef: 'synthetic/evidence.json' },
      latestRecoveryProposal: { title: '检查后继续', summary: '核对当前观察结果，再通过 CLI 决定下一步。', evidenceRefs: ['synthetic/evidence.json'] },
      appMap: { mapRef: 'synthetic/atlas.json', screenCount: 3, stateCount: 4, transitionCount: 2, pathCount: 2, coverageStatus: 'partial', pathIds: ['welcome-workspace', 'settings-return'] },
      suggestedCommands: [{ key: 'inspect', label: 'Inspect run', command: 'triton workspace inspect synthetic-run-001 --json' }],
    },
    paths: [
      { pathId: 'welcome-workspace', name: 'Welcome to workspace', status: 'verified', confirmed: true, replayable: true, requiresVLM: false, health: 'healthy', sourceRuns: ['synthetic-run-001'], suggestedCommands: [{ key: 'path-run', label: 'Replay path', command: 'triton test run synthetic/welcome.tritontest.yaml --json' }] },
      { pathId: 'settings-return', name: 'Settings return', status: 'blocked', confirmed: false, replayable: false, requiresVLM: true, health: 'unhealthy', sourceRuns: ['synthetic-run-002'], suggestedCommands: [] },
    ],
    evidenceRefs: ['synthetic/evidence.json'],
  };
  if (state === 'empty') {
    fixture.paths = [];
    fixture.run.suggestedCommands = [];
    fixture.run.appMap = { ...fixture.run.appMap, pathCount: 0, pathIds: [], coverageStatus: 'unknown' };
  }
  if (state === 'failed') {
    fixture.run.status = 'failed';
    fixture.run.latestPause = { reason: '观察结果尚未确认，检查失败证据', evidenceRef: 'synthetic/failure.json' };
  }
  if (state === 'long') {
    fixture.run.goal = '长文本场景：保持完整任务、失败原因和恢复路径可读，不截断关键信息。'.repeat(8);
    fixture.run.app.name = '跨多个工作区的合成验证应用名称'.repeat(5);
    fixture.run.appMap.mapRef = 'synthetic/' + 'long-path-segment-'.repeat(16) + 'atlas.json';
    fixture.paths[0].name = '从欢迎页面进入工作区并检查所有恢复路径'.repeat(5);
    fixture.paths[0].sourceRuns = ['synthetic-long-source-run-'.repeat(12)];
  }
  return fixture;
}
