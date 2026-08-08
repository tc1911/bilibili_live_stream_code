import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig({
  base: './', // [Fix] 相对路径, 兼容 pywebview 以 file:// 加载 dist/index.html
  plugins: [vue()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') }
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'index.html'),
        // 注意: vite 的 HTML 输出文件名 = 源文件相对路径, 与 input key 无关,
        // 因此悬浮窗页面必须叫 danmu-overlay.html 才能匹配 main.py 的加载路径
        overlay: path.resolve(__dirname, 'danmu-overlay.html')
      }
    }
  }
})