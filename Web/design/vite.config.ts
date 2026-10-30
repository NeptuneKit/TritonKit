import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { reviewPlugin } from '@linhey/rhine-design/review/vite';

export default defineConfig({
  root: fileURLToPath(new URL('.', import.meta.url)),
  base: './',
  plugins: [react(), reviewPlugin({ catalog: './catalog.tsx' })],
  server: { host: '127.0.0.1', port: 34127, strictPort: true },
  preview: { host: '127.0.0.1', port: 34128, strictPort: true },
  build: { outDir: '../dist-review', emptyOutDir: true },
});
