# Integration and diagnosis

## Supported baseline

Rhine Design 0.10.0 ships TypeScript/TSX, CSS and SVG source for React 19 + Vite. Install `@linhey/rhine-design`; GitHub remains `linhay/rhine-design`. Check the installed package's engine and peer dependencies. Node 24 is the development baseline. Do not assume precompiled JavaScript, arbitrary SSR support or a complete dark theme.

```tsx
import { Button, Surface, Text } from '@linhey/rhine-design';

export function Example() {
  return (
    <div className="rhine-theme">
      <Surface>
        <Text as="h2" variant="section">工作空间</Text>
        <Button onClick={() => { /* host action */ }}>继续</Button>
      </Surface>
    </div>
  );
}
```

## Integration invariants

Version 0.4.0 also exports `ThemeProvider`, `useTheme`, `themes`, `ThemeName` and `ThemeProviderProps` from `@linhey/rhine-design/theme` (not in npm 0.3.0). Read `docs/THEMING.md` from the verified package root. For a standalone skill installation without the package, see [the theme contract snapshot](https://github.com/linhay/rhine-design/blob/cfcb400fa213d9905eae1cab5dcb8ab8f817e03f/docs/THEMING.md) at commit `cfcb400fa213d9905eae1cab5dcb8ab8f817e03f` (0.10.0 source baseline). This fixed snapshot does not track main or establish availability in another installed version; prefer that version's own contract and implementation. This entry loads base and built-in theme CSS and renders the `.rhine-theme` root. Use `defaultTheme` for local state, or `theme` with `onThemeChange` for host state; storage and URL preferences remain with the host. Sibling providers are supported; nested providers throw. Do not wrap it in another themed root or key the subtree by theme. Gallery decoration is excluded from the public theme CSS.

Version 0.5.0 adds `Background` with canvas/content/sidebar/surface/overlay/media roles. `decoration="auto"` is the default: only canvas uses theme texture; content and AppShell default to plain backgrounds. Use `appearance` for local color/text/texture/size overrides and theme-root scene tokens for shared configuration. Background is paint only, not a new theme root or modal. Preview `#backgrounds` shows only the selected theme and follows the theme picker. Check installed exports before adopting this API; it is not in npm 0.4.0.

- The entry imports CSS automatically. Keep the package's entry and CSS `sideEffects` declarations so production tree shaking retains styles.
- Put `.rhine-theme` at the page root. Do not transform, clip or apply containment to it: overlays portal to the nearest theme root and need its variables and reduced-motion settings.
- For a locally linked checkout, use Vite `resolve.dedupe: ['react', 'react-dom']`. Duplicate React can break hooks; do not patch component state to mask this.
- Preserve SVG `?no-inline` handling. Logo uses a shared geometric master; missing symbols in production warrant checking the emitted SVG asset before replacing the logo.
- Reuse tokens for layout and state styling. The arknights preset uses a dark palette; a general light/dark/system color-mode API is not provided. Logo color remains independent of the component theme.

## Host responsibilities

Pass controlled form values, data, sorting/pagination intentions and operation results through the documented APIs. The host owns network requests, debouncing, IME composition, cancellation and stale-response protection. Do not replace server filtering with an unrequested full-data download.

Await actual copy/confirm outcomes. Errors remain actionable; busy state preserves meaningful focus. Inspect overlay focus return, Escape and keyboard navigation in the browser when changing those interactions. Progress with unknown duration is indeterminate; startup animation ends when the host is ready rather than imposing a decorative delay.

## Upgrade and feedback

Check the installed version against this skill's metadata, then consult `CHANGELOG.md`. Refresh the copied skill together with the package; keep local customizations when comparing versions. If types and docs disagree, use source for the immediate API and repair the stale reference when in scope.

For reproducible feedback record package version, component/API, relevant source or reference path, expected and actual behavior, and the smallest reproduction. Public reports must exclude private host payloads and credentials. For missing components, styles or states, follow [Report missing components and styles](../SKILL.md#report-missing-components-and-styles): check for duplicates and directly file or supplement an issue in `linhay/rhine-design`, without asking for confirmation each time.
