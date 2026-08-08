<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue';
import { useBridge } from '@/api/bridge';

const {
  getAppConfig,
  sendDanmu,
  toggleDanmuOverlay,
  getOverlayState,
  setOverlayAlwaysOnTop,
  setOverlayOpacity,
  startOverlayMove,
  overlayGetPosition,
  overlayDrag,
} = useBridge();

const messages = ref([]);
const inputMsg = ref('');
const isLinux = ref(false);
const isLocked = ref(false);
const isAlwaysOnTop = ref(true);
const opacity = ref(0.92);
const autoScroll = ref(true);
const listRef = ref(null);

const addMessage = (data) => {
  messages.value.push(data);
  if (messages.value.length > 200) messages.value.shift();
  if (autoScroll.value) {
    nextTick(() => scrollToBottom());
  }
};

const scrollToBottom = () => {
  if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight;
};

const onListScroll = () => {
  if (!listRef.value) return;
  const { scrollTop, scrollHeight, clientHeight } = listRef.value;
  autoScroll.value = scrollHeight - scrollTop - clientHeight < 50;
};

window.onDanmuMessage = (data) => addMessage(data);

const sendReply = async () => {
  const msg = inputMsg.value.trim();
  if (!msg) return;
  const res = await sendDanmu(msg);
  if (res.code === 0) {
    inputMsg.value = '';
  } else {
    addMessage({ type: 'system', msg: `发送失败: ${res.msg || '未知错误'}` });
  }
};

const toggleOnTop = async () => {
  const res = await setOverlayAlwaysOnTop(!isAlwaysOnTop.value);
  if (res && res.code === 0) isAlwaysOnTop.value = res.always_on_top;
};

const toggleLock = () => {
  isLocked.value = !isLocked.value;
};

const onOpacityInput = async (e) => {
  const v = parseFloat(e.target.value);
  opacity.value = v;
  await setOverlayOpacity(v);
};

const closeOverlay = () => {
  toggleDanmuOverlay();
};

// --- 拖动 (锁定时不响应) ---
const dragState = ref({ wx: 0, wy: 0, mx: 0, my: 0 });

const onPointerDown = async (e) => {
  if (isLocked.value) return;
  if (e.target.closest('button, input')) return;

  if (isLinux.value) {
    const res = await startOverlayMove();
    if (res && res.code === 0) return;
  }

  const pos = await overlayGetPosition();
  if (pos) {
    dragState.value = { wx: pos.x, wy: pos.y, mx: e.screenX, my: e.screenY };
    if (e.target.setPointerCapture) e.target.setPointerCapture(e.pointerId);
  }
};

const onPointerMove = (e) => {
  if (e.target.hasPointerCapture && e.target.hasPointerCapture(e.pointerId)) {
    overlayDrag(dragState.value.wx + (e.screenX - dragState.value.mx), dragState.value.wy + (e.screenY - dragState.value.my));
  }
};

const onPointerUp = (e) => {
  if (e.target.hasPointerCapture && e.target.hasPointerCapture(e.pointerId)) {
    e.target.releasePointerCapture(e.pointerId);
  }
};

onMounted(async () => {
  const cfg = await getAppConfig();
  isLinux.value = !!(cfg && cfg.is_linux);
  const st = await getOverlayState();
  if (st && st.code === 0) {
    isAlwaysOnTop.value = st.always_on_top;
    opacity.value = st.opacity;
  }
});

onUnmounted(() => {
  window.onDanmuMessage = null;
});
</script>

<template>
  <div class="overlay-root" :style="{ opacity: opacity }">
    <!-- 拖拽栏 -->
    <div
      class="overlay-drag pywebview-drag-region"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
    >
      <span class="drag-title">弹幕</span>
      <span v-if="isLocked" class="lock-hint">已锁定</span>
      <div class="drag-controls">
        <button class="ctl-btn" :class="{ active: isAlwaysOnTop }" :title="isAlwaysOnTop ? '取消置顶' : '置顶显示'" @click="toggleOnTop">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 3l14 8-6 2-3 7-3-7-6-2z"></path></svg>
        </button>
        <button class="ctl-btn" :class="{ active: isLocked }" :title="isLocked ? '解锁' : '锁定位置'" @click="toggleLock">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="11" width="16" height="9" rx="2"></rect><path d="M8 11V7a4 4 0 0 1 8 0v4"></path></svg>
        </button>
        <button class="ctl-btn" title="关闭悬浮窗" @click="closeOverlay">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"></path></svg>
        </button>
      </div>
    </div>

    <!-- 不透明度滑条 -->
    <div class="opacity-row">
      <span class="opacity-label">不透明度</span>
      <input type="range" min="0.3" max="1" step="0.01" :value="opacity" @input="onOpacityInput" class="opacity-slider" :disabled="isLocked">
      <span class="opacity-value">{{ Math.round(opacity * 100) }}%</span>
    </div>

    <!-- 弹幕列表 -->
    <div class="message-list" ref="listRef" @scroll="onListScroll">
      <div v-if="messages.length === 0" class="empty">等待弹幕...</div>
      <div v-for="(msg, index) in messages" :key="index" class="message-row">
        <template v-if="msg.type === 'danmu'">
          <span class="uname">{{ msg.uname }}</span>
          <span class="danmu-msg">: {{ msg.msg }}</span>
        </template>
        <template v-else-if="msg.type === 'interact'">
          <span class="sys interact"><span class="uname">{{ msg.uname }}</span> {{ msg.msg }}</span>
        </template>
        <template v-else-if="msg.type === 'gift'">
          <span class="sys gift"><span class="uname">{{ msg.uname }}</span> {{ msg.action }} {{ msg.gift_name }} x {{ msg.num }}</span>
        </template>
        <template v-else>
          <span class="sys">{{ msg.msg }}</span>
        </template>
      </div>
    </div>

    <!-- 回弹幕 -->
    <div class="reply-area">
      <input
        type="text"
        v-model="inputMsg"
        placeholder="回弹幕..."
        @keyup.enter="sendReply"
      >
      <button @click="sendReply">发送</button>
    </div>
  </div>
</template>

<style scoped>
.overlay-root {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: rgba(18, 20, 24, 0.78);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  overflow: hidden;
  color: #E8EAED;
  font-family: "PingFang SC", "Microsoft YaHei", "WenQuanYi Micro Hei", sans-serif;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.35);
  backdrop-filter: blur(6px);
}

.overlay-drag {
  height: 30px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 8px;
  background: rgba(255, 255, 255, 0.04);
  cursor: grab;
}
.overlay-drag:active { cursor: grabbing; }

.drag-title { font-size: 12px; font-weight: 600; color: rgba(255,255,255,0.75); }
.lock-hint { font-size: 10px; color: #8AB4F8; background: rgba(138,180,248,0.15); padding: 1px 6px; border-radius: 8px; }

.drag-controls {
  margin-left: auto;
  display: flex;
  gap: 2px;
  -webkit-app-region: no-drag;
}
.ctl-btn {
  width: 24px; height: 24px;
  background: transparent;
  border: none;
  border-radius: 6px;
  color: rgba(255,255,255,0.65);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}
.ctl-btn:hover { background: rgba(255,255,255,0.12); color: #fff; }
.ctl-btn.active { color: #8AB4F8; background: rgba(138,180,248,0.18); }

.opacity-row {
  flex-shrink: 0;
  padding: 4px 12px;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  display: flex;
  align-items: center;
  gap: 8px;
}
.opacity-label {
  font-size: 11px;
  color: rgba(255,255,255,0.5);
  flex-shrink: 0;
}
.opacity-value {
  font-size: 11px;
  color: rgba(255,255,255,0.6);
  width: 34px;
  text-align: right;
  flex-shrink: 0;
}
.opacity-slider {
  flex: 1;
  min-width: 0;
  height: 3px;
  accent-color: #8AB4F8;
  cursor: pointer;
}

.message-list {
  flex: 1;
  overflow-y: auto;
  padding: 8px 10px;
  font-size: 13px;
  line-height: 1.5;
  scrollbar-width: thin;
  scrollbar-color: rgba(255,255,255,0.2) transparent;
}
.message-list::-webkit-scrollbar { width: 4px; }
.message-list::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 2px; }

.empty { color: rgba(255,255,255,0.35); text-align: center; padding: 30px 0; font-size: 12px; }

.message-row { margin-bottom: 6px; word-break: break-all; }
.uname { color: #8AB4F8; font-weight: 600; margin-right: 4px; }
.danmu-msg { color: #E8EAED; }

.sys { display: block; text-align: center; font-size: 11px; color: rgba(255,255,255,0.55); padding: 2px 8px; border-radius: 8px; background: rgba(255,255,255,0.06); }
.sys.interact { color: rgba(255,255,255,0.6); }
.sys.gift { color: #FF9ECB; }

.reply-area {
  flex-shrink: 0;
  display: flex;
  gap: 6px;
  padding: 8px;
  border-top: 1px solid rgba(255,255,255,0.06);
  background: rgba(255,255,255,0.04);
}
.reply-area input {
  flex: 1;
  min-width: 0;
  background: rgba(255,255,255,0.08);
  border: 1px solid rgba(255,255,255,0.12);
  border-radius: 14px;
  padding: 5px 12px;
  font-size: 12px;
  color: #E8EAED;
  outline: none;
}
.reply-area input::placeholder { color: rgba(255,255,255,0.4); }
.reply-area input:focus { border-color: #8AB4F8; }
.reply-area button {
  flex-shrink: 0;
  background: #00aeec;
  color: white;
  border: none;
  border-radius: 14px;
  padding: 5px 14px;
  font-size: 12px;
  cursor: pointer;
}
.reply-area button:hover { background: #00a1d6; }
</style>
