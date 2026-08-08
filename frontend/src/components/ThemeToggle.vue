<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { useBridge } from '@/api/bridge';
import { getCurrentTheme, setTheme } from '@/theme';

const { setTheme: saveThemeBackend } = useBridge();
const isDark = ref(false);
let observer = null;

const toggleTheme = async () => {
  isDark.value = !isDark.value;
  const theme = isDark.value ? 'dark' : 'light';
  setTheme(theme);
  await saveThemeBackend(theme);
};

onMounted(() => {
  isDark.value = getCurrentTheme() === 'dark';
  // 后端配置恢复主题时 (App.vue onMounted) 同步按钮状态
  observer = new MutationObserver(() => {
    isDark.value = document.documentElement.getAttribute('data-theme') === 'dark';
  });
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
});

onUnmounted(() => {
  if (observer) observer.disconnect();
});
</script>

<template>
  <button class="theme-btn" @click="toggleTheme" :title="isDark ? '切换到浅色模式' : '切换到深色模式'">
    <svg v-if="!isDark" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
    </svg>
    <svg v-else width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="5"></circle>
      <line x1="12" y1="1" x2="12" y2="3"></line>
      <line x1="12" y1="21" x2="12" y2="23"></line>
      <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
      <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
      <line x1="1" y1="12" x2="3" y2="12"></line>
      <line x1="21" y1="12" x2="23" y2="12"></line>
      <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
      <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
    </svg>
  </button>
</template>

<style scoped>
.theme-btn {
  width: 32px;
  height: 32px;
  margin-right: 4px;
  background: transparent;
  border: none;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--text-sub);
  transition: background 0.2s, color 0.2s;
  -webkit-app-region: no-drag;
}
.theme-btn:hover {
  background: var(--hover-bg);
  color: var(--text-main);
}
</style>
