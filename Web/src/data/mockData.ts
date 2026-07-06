import type { HierarchyScene } from "../types";

export const hierarchyScenes: Record<string, HierarchyScene> = {
  ios: {
    platform: "ios",
    rootId: "window",
    viewport: { width: 390, height: 844 },
    controllerContext: {
      activeControllerId: "main-controller",
      activeControllerName: "MainTabBarController",
      activeControllerClassName: "MainTabBarController",
      source: "runtime-tree",
      stack: [
        { id: "main-controller", className: "MainTabBarController", name: "MainTabBarController" },
        { id: "feed-controller", className: "FeedViewController", name: "FeedViewController" },
      ],
    },
    nodes: [
      node("window", null, "UIWindowScene", "mainScene", 0, 0, 390, 844, 0),
      node("root", "window", "UIView", "rootView", 0, 0, 390, 844, 1),
      node("stack", "root", "UIStackView", "questionList", 16, 96, 358, 520, 2),
      node("back", "root", "UIButton", "backButton", 16, 52, 44, 44, 2, "backButton"),
      node("title", "root", "UILabel", "titleLabel", 72, 56, 180, 28, 2),
      node("tabbar", "root", "UITabBar", "tabbar", 0, 760, 390, 84, 2),
      node("server-tab", "tabbar", "UIButton", "serverTab", 0, 760, 98, 84, 3),
      node("photos-tab", "tabbar", "UIButton", "photosTab", 98, 760, 98, 84, 3),
      node("music-tab", "tabbar", "UIButton", "musicTab", 196, 760, 97, 84, 3),
      node("settings-tab", "tabbar", "UIButton", "settingsTab", 293, 760, 97, 84, 3),
    ],
  },
};

function node(
  id: string,
  parentId: string | null,
  type: string,
  name: string,
  x: number,
  y: number,
  width: number,
  height: number,
  depth: number,
  accessibilityIdentifier = name
) {
  return {
    id,
    parentId,
    type,
    name,
    frame: { x, y, width, height },
    depth,
    visible: true,
    interactive: type === "UIButton",
    color: "#1677FF",
    source: "runtime-tree",
    view: { accessibilityIdentifier, accessibilityLabel: name, alpha: 1 },
    raw: { source: "runtime-tree", role: type },
  };
}
