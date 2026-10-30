import type { DevicePlatform } from "../src/types";
import { InspectorPanel } from "../src/components/InspectorPanel";
import { SyntheticContextProvider } from "./SyntheticContext";

export type InspectorSceneProps = {
  platform?: DevicePlatform;
  state?: string;
  copyText?: (text: string) => Promise<void>;
};

export function InspectorScene({ platform = "ios", state = "ready", copyText }: InspectorSceneProps) {
  return <SyntheticContextProvider platform={platform} state={state} selectedNode>
    <InspectorPanel nodeId="design-inspector" copyText={copyText} />
  </SyntheticContextProvider>;
}
