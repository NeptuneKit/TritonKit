## GetTokens Ant Design design-language contract

When a GetTokens task says “对齐 AntD”, “只保留 AntD”, “AntD 设计语言”, or links to Ant Design spec pages such as docs/spec/introduce-cn or docs/spec/colors-cn, treat it as a design-system contract, not just a component-library import.

Use this source order:

1. Run `antd design.md --format json` for the executable local baseline.
2. Read official Ant Design spec pages when network is available.
3. Query component docs through `antd info`, `antd doc`, `antd token`, or `antd semantic` before changing component code.

The default Ant Design v6 design-language baseline for GetTokens is:

- Values: Natural, Certain, Meaningful, Growing. Prefer predictable, state-clear, purpose-driven enterprise UI over decorative custom styling.
- Color: only Ant Design palette colors are allowed in runtime color literals. Use primary #1677FF, success #52C41A, warning #FAAD14, error/red #FF4D4F / #F5222D, info #1677FF, preset palettes from @ant-design/colors, and neutral colors #FFFFFF, #FAFAFA, #F5F5F5, #F0F0F0, #D9D9D9, #BFBFBF, #8C8C8C, #595959, #434343, #262626, #1F1F1F, #141414, #000000. Do not mint provider, chart, accent, or status colors outside this set. Transparent overlays and shadows should derive from black alpha or color-mix() with an allowed palette color.
- Typography: default product UI uses 14px body text, system font stack, and only 400 / 600 weights for chrome. Avoid 500/650/700+ as product UI emphasis unless an AntD component token requires it.
- Spacing: snap layout gaps and padding to the 4px grid. Avoid arbitrary one-off spacing unless it comes from an AntD component token.
- Radius: controls use 6px, surfaces use 8px, small tags/chips use 4px, pill radius is reserved for avatars/badges/dots.
- Elevation: flat-first. Borders and tonal contrast carry hierarchy; shadows are for genuinely floating surfaces such as modal/dropdown/popover.
- Components: prefer AntD components and AntD component tokens. Primary buttons are reserved for the single dominant action per surface; secondary actions should be default/text variants.

For GetTokens implementation, encode this contract in tests or static gates when possible. A change is not complete if it only imports AntD while preserving custom visual language, arbitrary colors, non-AntD radii, or old GetTokens visual primitives.
