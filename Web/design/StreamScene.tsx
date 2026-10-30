import { useEffect, useState } from 'react';
import { StreamPanel } from '../src/components/StreamPanel';
import { SyntheticContextProvider } from './SyntheticContext';

export type StreamSceneProps = {
  nodeId?: string;
  platform?: 'ios' | 'android' | 'harmony';
  state?: string;
};

export const syntheticScreen = `<svg xmlns="http://www.w3.org/2000/svg" width="390" height="844" viewBox="0 0 390 844">
<rect width="390" height="844" fill="#10151d"/>
<rect x="16" y="72" width="358" height="148" rx="16" fill="#202a36"/>
<text x="32" y="118" fill="#edf2f7" font-size="24" font-family="sans-serif">Synthetic workspace</text>
<text x="32" y="154" fill="#b8c8d8" font-size="16" font-family="sans-serif">Read-only device preview</text>
<rect x="24" y="260" width="342" height="56" rx="8" fill="#5b8dba"/>
<text x="44" y="296" fill="white" font-size="18" font-family="sans-serif">Synthetic action</text>
<text x="32" y="790" fill="#b8c8d8" font-size="15" font-family="sans-serif">No device connection</text>
</svg>`;

export function StreamScene({ nodeId = 'synthetic-stream', platform = 'ios', state = 'ready' }: StreamSceneProps) {
  const [imageUrl, setImageUrl] = useState('');
  useEffect(() => {
    const blob = new Blob([state === 'image-error' ? 'synthetic invalid image' : syntheticScreen], { type: 'image/svg+xml' });
    const url = URL.createObjectURL(blob);
    setImageUrl(url);
    return () => { URL.revokeObjectURL(url); };
  }, [state]);

  return <SyntheticContextProvider platform={platform} state={state}>
    <div style={{ height: 720, maxWidth: '100%', minWidth: 0 }}>
      {imageUrl && <StreamPanel nodeId={nodeId} streamImageUrl={(request) => `${imageUrl}#${request.platform}-${request.fps}-${request.connectTime}`} />}
    </div>
  </SyntheticContextProvider>;
}
