/** Observe the preview container, not the image that is removed while paused. */
export function observeStreamVisibility(element: HTMLElement, onChange: (visible: boolean) => void): () => void {
  const document = element.ownerDocument;
  const view = document.defaultView as (Window & typeof globalThis) | null;
  if (!view) {
    onChange(false);
    return () => {};
  }

  let disposed = false;
  let pageHidden = false;
  // Wait for the first intersection result before opening a network stream.
  let intersects = typeof view.IntersectionObserver !== "function";
  let previous: boolean | undefined;

  const hasVisibleGeometry = () => {
    if (!element.isConnected || element.getClientRects().length === 0) return false;
    const rect = element.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0 || rect.bottom <= 0 || rect.right <= 0
      || rect.top >= view.innerHeight || rect.left >= view.innerWidth) return false;

    for (let node: Element | null = element; node; node = node.parentElement) {
      const style = view.getComputedStyle(node);
      if (node.hasAttribute("hidden") || style.display === "none" || style.visibility === "hidden"
        || style.visibility === "collapse" || style.opacity === "0" || style.contentVisibility === "hidden") return false;
    }
    return true;
  };
  const update = () => {
    if (disposed) return;
    const visible = !pageHidden && document.visibilityState === "visible" && intersects && hasVisibleGeometry();
    if (visible !== previous) {
      previous = visible;
      onChange(visible);
    }
  };
  const onPageHide = () => { pageHidden = true; update(); };
  const onPageShow = () => { pageHidden = false; update(); };

  const intersection = typeof view.IntersectionObserver === "function"
    ? new view.IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.target !== element) continue;
        intersects = entry.isIntersecting && entry.intersectionRect.width > 0 && entry.intersectionRect.height > 0;
      }
      update();
    }) : null;
  intersection?.observe(element);
  const resize = typeof view.ResizeObserver === "function" ? new view.ResizeObserver(update) : null;
  resize?.observe(element);
  const mutation = typeof view.MutationObserver === "function" ? new view.MutationObserver(update) : null;
  // Ancestor-only attributes avoid observing frame/overlay churn within the preview.
  for (let node: Element | null = element; node; node = node.parentElement) {
    mutation?.observe(node, { attributes: true, attributeFilter: ["class", "style", "hidden"] });
  }
  document.addEventListener("visibilitychange", update);
  view.addEventListener("pagehide", onPageHide);
  view.addEventListener("pageshow", onPageShow);
  view.addEventListener("resize", update);
  view.addEventListener("scroll", update, true);
  view.addEventListener("transitionend", update, true);
  view.addEventListener("animationend", update, true);
  update();

  return () => {
    disposed = true;
    intersection?.disconnect();
    resize?.disconnect();
    mutation?.disconnect();
    document.removeEventListener("visibilitychange", update);
    view.removeEventListener("pagehide", onPageHide);
    view.removeEventListener("pageshow", onPageShow);
    view.removeEventListener("resize", update);
    view.removeEventListener("scroll", update, true);
    view.removeEventListener("transitionend", update, true);
    view.removeEventListener("animationend", update, true);
  };
}

/** Replace a multipart network image explicitly; removing its DOM node alone can leave it downloading. */
export function releaseStreamImage(image: HTMLImageElement): void {
  image.removeAttribute("srcset");
  image.src = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";
}

/** React StrictMode can detach and reattach a ref without recreating the image element. */
export function attachStreamImage(image: HTMLImageElement, source: string): void {
  if (image.getAttribute("src") !== source) image.src = source;
}

export function hasCurrentStreamFrame(image: HTMLImageElement): boolean {
  return image.naturalWidth > 0 && image.naturalHeight > 0 && image.currentSrc !== ""
    && !image.currentSrc.startsWith("data:") && image.currentSrc === image.src;
}

/** Multipart images may expose their first frame before firing load. Probe only during startup, for at most 45s. */
export function observeFirstStreamFrame(image: HTMLImageElement, onFrame: () => void): () => void {
  const view = image.ownerDocument.defaultView;
  if (!view) return () => {};
  let stopped = false;
  const deadline = view.performance.now() + 45_000;
  let timer: number | undefined;
  const stop = () => {
    stopped = true;
    if (timer !== undefined) view.clearTimeout(timer);
    timer = undefined;
    image.removeEventListener("load", check);
    image.removeEventListener("error", stop);
  };
  const check = () => {
    if (stopped) return;
    if (timer !== undefined) view.clearTimeout(timer);
    timer = undefined;
    const remaining = deadline - view.performance.now();
    if (remaining <= 0) {
      stop();
    } else if (hasCurrentStreamFrame(image)) {
      stop();
      onFrame();
    } else {
      timer = view.setTimeout(check, Math.min(100, remaining));
    }
  };
  image.addEventListener("load", check);
  image.addEventListener("error", stop);
  check();
  return stop;
}
