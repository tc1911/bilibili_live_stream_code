"""窗口引用注册表

不能把 pywebview Window 对象挂在 ApiService (js_api) 上:
pywebview 会递归遍历 js_api 的属性树来生成 JS 桥, Window 对象(及其 native Qt 控件)
会触发遍历错误, 导致前端所有 window.pywebview.api 调用失败。

Qt 原生控件操作统一经 overlay_controller 委托到 Qt 主线程执行
(js_api 回调线程直接操作 QWidget 会崩溃)。
"""

overlay_window = None
overlay_visible = False  # 悬浮窗可见性 (pywebview Window 没有 visible 属性, 自己维护)
overlay_controller = None


def invoke_overlay_controller(method):
    """排队在主线程执行悬浮窗控制器的槽函数 (可跨线程调用)"""
    controller = overlay_controller
    if controller is None:
        return
    try:
        from qtpy.QtCore import QMetaObject, Qt
        QMetaObject.invokeMethod(controller, method, Qt.QueuedConnection)
    except Exception:
        pass


def set_overlay_ontop(on):
    controller = overlay_controller
    if controller is None:
        return
    try:
        controller.set_ontop_state(bool(on))
    except Exception:
        pass
