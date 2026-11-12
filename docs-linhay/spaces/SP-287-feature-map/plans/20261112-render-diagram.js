async (page) => {
  // Open the task-owned loopback feature-map page before invoking this export snippet.
  const sourceURL = new URL(page.url());
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(sourceURL.hostname) || !sourceURL.pathname.endsWith('/feature-map.html')) {
    throw new Error('Select the task-owned loopback feature-map.html before exporting');
  }
  const context = await page.context().browser().newContext({ viewport: { width: 1900, height: 1800 }, deviceScaleFactor: 2 });
  const exportPage = await context.newPage();
  try {
  await exportPage.goto(sourceURL.href);
  page = exportPage;
  await page.waitForFunction(() => !!window.__diagram && document.fonts.status === 'loaded');
  await page.addStyleTag({ content: '*{transition:none!important;animation:none!important}body{padding:0!important}.page{margin:0!important}.head,.detail,.foot{display:none!important}.scroller{border:0!important;border-radius:0!important;overflow:visible!important;width:1800px!important}.stage{width:1800px!important;height:1560px!important}.canvas{transform:none!important;border-radius:0!important}' });
  await page.evaluate(async () => {
    window.__diagram.clearSelection();
    document.documentElement.removeAttribute('data-theme');
    window.scrollTo(0, 0);
    await document.fonts.ready;
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
  const geometry = await page.evaluate(() => {
    const r = document.querySelector('.canvas').getBoundingClientRect();
    return { viewport: window.innerWidth, width: r.width, height: r.height, selection: document.querySelectorAll('.node.selected').length, nodes: document.querySelectorAll('.node').length, edges: document.querySelectorAll('.connection').length, brokenImages: [...document.images].filter(i=>!i.complete||!i.naturalWidth).length };
  });
  if (geometry.width !== 1800 || geometry.selection !== 0 || geometry.nodes !== 22 || geometry.brokenImages !== 0) throw new Error(JSON.stringify(geometry));
  await page.locator('.canvas').screenshot({ path: 'output/playwright/sp287-features-light-v3.png', animations: 'disabled', scale: 'device' });
  await page.evaluate(async () => {
    document.documentElement.setAttribute('data-theme', 'dark');
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
  await page.locator('.canvas').screenshot({ path: 'output/playwright/sp287-features-dark-v3.png', animations: 'disabled', scale: 'device' });
  return { geometry, deviceScaleFactor: await page.evaluate(() => window.devicePixelRatio), export: 'Chromium element screenshot, animations disabled, viewport asserted' };
  } finally { await context.close(); }
}
