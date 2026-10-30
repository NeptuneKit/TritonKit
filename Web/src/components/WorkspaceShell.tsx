import type { ReactNode } from 'react';
import { Badge, Text } from '@linhey/rhine-design';
import './workspaceShell.css';

export function WorkspaceShell({ children }: { children: ReactNode }) {
  return <div className="rhine-workspace-shell">
    <header className="rhine-workspace-header">
      <div className="rhine-workspace-brand"><Text as="h1" variant="section">TRITON</Text><Text tone="muted">设备工作台</Text></div>
      <Badge>只读工作台</Badge>
    </header>
    <main className="rhine-workspace-main" aria-label="可分屏工作台">{children}</main>
  </div>;
}
