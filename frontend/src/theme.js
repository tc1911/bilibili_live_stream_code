const THEME_KEY = 'bili-live-theme';

export function getSystemTheme() {
  return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function getStoredTheme() {
  return localStorage.getItem(THEME_KEY);
}

export function applyTheme(theme) {
  if (!theme) {
    theme = getStoredTheme() || getSystemTheme();
  }
  document.documentElement.setAttribute('data-theme', theme);
  return theme;
}

export function setTheme(theme) {
  localStorage.setItem(THEME_KEY, theme);
  applyTheme(theme);
}

export function getCurrentTheme() {
  return applyTheme();
}
