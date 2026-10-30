# API map

All paths are relative to the matching package root. `package.json` exports, `components/index.ts` and the separate `components/theme.tsx` entry are the public export authority. This index locates APIs; exact props come from the installed source, not from remembered examples.

| Exports | Source |
| --- | --- |
| ChatThread, ChatCard; ChatEntry, ChatMessage, ChatEvent, ChatMember, ChatStatus, ChatThreadProps, ChatCardProps (source candidate after 0.11.0) | `components/Chat.tsx`, `docs/AGENT_CHAT.md`; stable IDs, history anchor, explicit resume, readOnly action slots |
| Checkbox `layout="row"`, CheckboxProps（自 0.10.0） | `components/Forms.tsx`、`docs/CHECKBOX_ROWS.md`；整行双行多选，默认 form 保持兼容；npm 0.9.1 不含此选项 |
| TrendChart, StackedBar；StatusTimeline.detail（0.5.0） | `components/Charts.tsx`、`components/StatusTimeline.tsx`；`docs/APPLICATION_COMPONENTS.md`，未知不补零；键盘逐点查看、按ID受控高亮/详情、valueFormatter |
| Background, AppShell（0.5.0）；AppShellToggle（0.8.0） | `components/Background.tsx`、`components/AppShell.tsx`；`docs/APPLICATION_COMPONENTS.md`；桌面open与临时drawerOpen独立，断点为容器CSS布局宽度 |
| AppShell.contentHeader（0.8.0） | `components/AppShell.tsx`；`docs/APPLICATION_COMPONENTS.md`；正文列常驻导航插槽，与正文滚动区分离，组合 AppShellToggle / Inline / 标题与上下文操作 |
| MediaCard, MediaViewer（0.5.0） | `components/Media.tsx`；中性画布，不嵌套主题 |
| Media 主题重设计（0.8.0） | `components/media-parity.css`；`docs/APPLICATION_COMPONENTS.md`；卡片、标签与查看器操作/信息栏随宿主主题，仅媒体画布中性；选择与重试独立 |
| DateField, DateRangePicker, NumberField, TreeSelect, RemoteMultiSelect（0.5.0） | `components/AdvancedForms.tsx`；请求、时区和查询由宿主负责；只读/校验/多选键盘及AntD/MUI保留差异见 `docs/ANTD_MUI_AUDIT.md` |
| 紧凑筛选（自 0.10.0，npm 0.9.1 不含） | `docs/COMPACT_FILTER_CONTROLS.md`；SegmentedControl `fullWidth`、DateRangePicker `compact`、RemoteMultiSelect `maxVisibleTags`、ListFilterBar `drawerDescription` / `drawerResult`；保持默认兼容、完整选择值及加载/错误反馈 |
| Date presets + confirmed custom range（组合，无新增导出） | `docs/DATE_RANGE_FILTER.md`、`preview/DateRangeFilterGallery.tsx`；复用 SegmentedControl + Button + Popover + DateRangePicker，宿主负责时区、预设和查询 |
| ThemeProvider, useTheme, themes, ThemeName, ThemeProviderProps (0.4.0；`@linhey/rhine-design/theme`) | `components/theme.tsx`；契约 `docs/THEMING.md` |
| OrbitBackdrop, OrbitBackdropProps (0.6.0) | `components/OrbitBackdrop.tsx`；契约 `docs/ORBIT_BACKDROP.md`；`components/orbitRenderer.ts` 为内部绘制实现 |
| NeutronStarBackdrop, NeutronStarBackdropProps (0.8.0) | `components/NeutronStarBackdrop.tsx`；契约 `docs/NEUTRON_STAR_BACKDROP.md`；Three.js drawing modules are internal |
| Logo | `components/Logo.tsx` |
| Text | `components/Typography.tsx` |
| Select | `components/Select.tsx` |
| Toolbar | `components/Toolbar.tsx` |
| Icon, IconButton, Link, CopyButton | `components/Actions.tsx` |
| ButtonLink（0.8.0） | `components/Actions.tsx`；`docs/COMPACT_ACCOUNT_PATTERNS.md`；原生 anchor/下载语义，同 Button 视觉，busy 保焦点并移除 href |
| Divider, Stack, Inline, Grid | `components/Layout.tsx` |
| Metric, KeyValue, DataTable, Pagination | `components/Data.tsx` |
| Checkbox, RadioGroup, Switch, Textarea, SearchField, Combobox | `components/Forms.tsx` |
| Dialog, Drawer (0.4.0), ConfirmDialog, Popover, Menu, Tooltip | `components/Overlays.tsx` |
| StatusTimeline, TimelineLegend (0.4.0) | `components/StatusTimeline.tsx`；历史证据，不计算健康评分 |
| TimelineLegend compact/items（0.8.0） | `components/StatusTimeline.tsx`；`docs/COMPACT_ACCOUNT_PATTERNS.md`；宿主短标签/完整规则，一行局部滚动，hover/focus/touch 详情 |
| StatusTimelineList（0.8.0） | `components/StatusTimelineList.tsx`、`docs/APPLICATION_COMPONENTS.md`；稳定行 ID、标题/摘要/紧凑时间条组合、单一详情，宿主保留请求与分页；展台 `/#monitoring` |
| SideNav, Breadcrumbs, Steps (0.4.0) | `components/Navigation.tsx` |
| Fieldset, ErrorSummary (0.4.0) | `components/FormWorkflow.tsx` |
| Toast | `components/Toast.tsx` |
| Button, Badge, Surface, SelectionCard, TextField, Tabs, SegmentedControl, Notice, Progress, Skeleton, Disclosure, EmptyState | `components/components.tsx`；Surface 的 `padding="none"` 仅取消表格容器外围内距，默认不变；此选项自 0.9.1 提供，见 `CHANGELOG.md` |

Additions in 0.11.0: `Tabs` / `TabItem` `description` and `status`, `Toast placement="floating"`, and `SegmentedControl size="compact"`. They are absent from npm 0.10.0. Pin 0.11.0 and read `CHANGELOG.md` before upgrading.

Primary contracts: `components/README.md` and `components/COMMON_COMPONENTS.md`. Find behavioral evidence in `tests/` and composition examples in `preview/`.

```sh
# From the resolved package root:
rg -n 'ConfirmDialog|DataTable|Combobox' components/index.ts components/*.tsx
rg -n 'ConfirmDialog|DataTable|Combobox' tests preview
```

API decisions that commonly matter:

- `Select` uses a native single-select; searchable candidates use `Combobox`.
- `SelectionCard.showIndicator=false` visually hides the native input while preserving keyboard focus, accessible state and card selection styling (0.8.0).
- `SelectionCard` uses checkbox semantics; the host determines single-selection policy. Do not nest other interactive controls in it.
- `Text`'s `as` chooses semantics; `variant` chooses visual hierarchy.
- `Logo` accepts `wordmark` and `label`; its `theme` affects the logo, not the full component library.
- `OrbitBackdrop` is decorative artwork with built-in pause / resume. Its `reducedMotion` prop can strengthen but never override system reduction; see `docs/ORBIT_BACKDROP.md` for visibility, narrow-window and fallback behavior. In 0.8.0, theme artwork uses an origami paper bird, originium crystals or a strawberry donut; `appearance="original"` preserves the initial orbit. It does not express loading or business progress.
- `NeutronStarBackdrop` preserves the separate neutron-star artwork. `appearance="theme"` follows existing theme tokens; `original` restores its deep-space palette without replacing the host control theme. It lazy-loads WebGL, freezes under reduction or visibility constraints, and retains static art on failure. It requires 0.8.0 or later; see `docs/NEUTRON_STAR_BACKDROP.md`.
- `Toast` presents one notification, not a global queue. `DataTable` is not a query or table-state engine.
- Components in `preview/` are demonstrations. Public API must resolve through a `package.json` export; theme APIs use the separate `/theme` entry.

Available since 0.8.0 (check installed exports): `ThemePicker` / `ThemePreview` in `components/ThemePicker.tsx`, contract `docs/THEME_PICKER.md`; `Dialog.navigation` in `components/Overlays.tsx`, contract `docs/SETTINGS_DIALOG.md`; shared floating CSS zoom behavior in `docs/FLOATING_OVERLAYS.md`.

Product review tooling (since 0.11.0): `/review` exports `defineReview`, URL helpers and scene/session types from `review/index.ts`; `/review/vite` exports Node-only `reviewPlugin` and `reviewProductionGuard` from `review/vite.mjs`, types in `review/vite.d.mts`. Never import the Vite entry into production UI. Read `docs/REVIEW_TOOL.md`; npm 0.10.0 does not contain these entries.

SideNav 行尾命令：`NavItem.actions` / `NavAction`，见 `docs/SIDE_NAV_ACTIONS.md`，真实展台 `#nav-actions`；未发布。

单输入即时搜索：TextField / TextFieldProps 的 `labelVisibility="hidden"` 保留非空名称；参见 `docs/SINGLE_SEARCH.md` 与 `#single-search`，未发布。搜索/异步与IME由宿主管理。

#41未发布：Button.contentAlign、Tabs.layout/TabsProps、Dialog.height/footer；先读 `docs/COMPACT_ACCOUNT_PATTERNS.md`、`docs/SETTINGS_DIALOG.md`、`docs/SUMMARY_TABS.md`，展台 `#compact-selection`。

#46未发布：Button.size="standard" | "large"；动作语义先读 `docs/BUTTON_ACTIONS.md`，展台 `#button-actions`。

#18 未发布：Dialog `description?`、settings CSS次序独立、`height/footer/navigation` 固定头尾与正文/长导航独立滚动；短屏右对齐动作及真实消费验证见 `docs/SETTINGS_DIALOG.md`，展台 `#settings-dialog`。
