# Task map

Resolve the matching package root as described in SKILL.md. Open the first relevant source; expand only when the task crosses domains.

| Task | First reference (relative to package root) | Implementation / example |
| --- | --- | --- |
| Agent chat, member grouping, inline cards, observation and history scrolling | `docs/AGENT_CHAT.md` (source candidate after 0.11.0) | `components/Chat.tsx`, `preview/ChatGallery.tsx`; `/#agent-chat`; host owns transitions, requests and permissions |
| Application shell, backgrounds, media, advanced inputs, controlled tables | `docs/APPLICATION_COMPONENTS.md` (0.5.0) | `preview/ExtensionsGallery.tsx`; `/#app-shell`, `/#advanced-forms`, `/#advanced-data`, `/#media` |
| Workspace header, duplicate page titles, optional breadcrumbs | `docs/APPLICATION_COMPONENTS.md` → 平级工作区顶部操作区 (source guideline) | `preview/ExtensionsGallery.tsx`; `/#app-shell`; keep status/actions, navigation restore and accessible page identity |
| Product design review shell, synthetic HTTP/platform scenes, static deployment | `docs/REVIEW_TOOL.md` (since 0.11.0; not npm 0.10.0) | `review/`, `examples/review/http`, `examples/review/platform`; separate `/review` and `/review/vite` exports |
| Theme integration, switching, controlled preferences | `docs/THEMING.md` (0.4.0) | `components/theme.tsx`, `preview/GalleryShell.tsx` |
| Scenario selection, navigation, form recovery, monitoring | `docs/INTERACTION_PATTERNS.md` (0.4.0; check installed version) | `preview/PatternGallery.tsx`; research in `docs/REFERENCE_RESEARCH.md` |
| Date presets, visible date ranges, custom-range drafts and confirmation | `docs/DATE_RANGE_FILTER.md` (source pattern using existing 0.6.0 APIs) | `preview/DateRangeFilterGallery.tsx`; `/#date-range-filter`; no public DateRangeFilter component |
| Visual direction, colors, spacing, layout | `docs/DESIGN_SYSTEM.md` | `components/tokens.css`, `components/Layout.tsx` |
| Spacing, grouping, card composition | `components/SPACING.md` (0.4.0 docs; existing gap API works in 0.3.0) | `components/Layout.tsx`, `preview/SpacingGallery.tsx`; `/#spacing` |
| Text hierarchy, line height, paragraphs, Chinese/Latin text, metrics | `components/TYPOGRAPHY.md` | `components/Typography.tsx`, `preview/LineHeightGallery.tsx`; `/#typography` |
| Logo, light/dark variants, wordmark | `components/README.md` → 品牌标志 | `components/Logo.tsx`, `components/assets/logo.svg` |
| Buttons, navigation, basic states | `components/README.md` → 组件契约 | `components/components.tsx` |
| Tabs with identity summaries and per-object status | `docs/SUMMARY_TABS.md` (local candidate; verify installed API) | `Tabs.description/status`, `preview/SummaryTabsGallery.tsx`; `/#summary-tabs`; 12/8/4/16/24 spacing, stable labels and accessible descriptions |
| Task-centered content reduction, borderless account summaries, credential actions, compact legends | `docs/COMPACT_ACCOUNT_PATTERNS.md` (source candidates; not npm 0.6.0) | `preview/CompactAccountGallery.tsx`; `/#compact-account`; ButtonLink + StatusTimelineList + TimelineLegend |
| Forms, selection, combobox, data tables | `components/COMMON_COMPONENTS.md` | Use API_MAP for the source file |
| Modal, menu, popover, tooltip, feedback | `components/COMMON_COMPONENTS.md` | `components/Overlays.tsx`, `components/Toast.tsx` |
| Transition, replay, cancellation, reduced motion | `components/MOTION.md` | `preview/`, `components/styles.css` |
| Startup sequence, logo assembly, ready handoff | `components/STARTUP.md` | Search `startup` in `preview/`; not a public Startup component |
| Orbit artwork, decorative Canvas, pause / resume, reduced motion | `docs/ORBIT_BACKDROP.md` (base 0.6.0, themed objects 0.8.0) | `components/OrbitBackdrop.tsx`, internal `components/orbitRenderer.ts`; `/#orbit` |
| Neutron-star artwork, themed WebGL, async loading, static fallback | `docs/NEUTRON_STAR_BACKDROP.md` (0.8.0) | `components/NeutronStarBackdrop.tsx`; `preview/NeutronStarGallery.tsx`; `/#neutron-star` |
| Missing capability or system coverage | `docs/DESIGN_SYSTEM_AUDIT.md` | Verify status against `components/index.ts` |
| Version upgrade | `CHANGELOG.md` | Installed `package.json`, current types |

Run the library showcase with `npm ci && npm run dev` in a source checkout. Default port is 18309; sections include `/#foundation`, `/#typography`, `/#brand`, `/#motion`, `/#startup` and `/#orbit`, plus `/#neutron-star` and `/#compact-account` in 0.8.0. Do not assume another project's server or local filesystem layout.

For host pages, keep product-specific drafts in the host project. The library's `preview/` demonstrates reusable behavior, not business APIs. Labels such as “candidate” or “preview” in motion docs identify experiments; check whether the behavior is actually exported before integrating it.

For 0.8.0 theme-comparison cards, settings navigation, or floating CSS zoom boundaries, read `docs/THEME_PICKER.md`, `docs/SETTINGS_DIALOG.md`, and `docs/FLOATING_OVERLAYS.md` respectively. Preview routes: `#theme-picker`, `#settings-dialog`, `#overlay-bounds`. Do not infer package availability from the main gallery.
