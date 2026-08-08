"""窗口引用注册表

不能把 pywebview Window 对象挂在 ApiService (js_api) 上:
pywebview 会递归遍历 js_api 的属性树来生成 JS 桥, Window 对象(及其 native Qt 控件)
会触发遍历错误, 导致前端所有 window.pywebview.api 调用失败。
"""

overlay_window = None
