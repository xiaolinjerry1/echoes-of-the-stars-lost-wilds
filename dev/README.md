# 开发验证

当前生产入口为 `verify_boot.tscn`（指向 `verify_survivor.gd`），包含94项实际场景回归。`preview_combat_feel.tscn`为可运行画面采集入口。

同目录的早期测试用于历史RPG和单资产验证，可能依赖已经退出生产流程的装备、精灵或旧回响机制。它们不属于v1.0全量自检入口。

公开仓库保留GDScript/场景验证与原创音效生成脚本；机器路径绑定的批量制作/发布Python脚本、Blender TCP服务配置、日志、临时渲染与缓存未发布。正式美术源文件保留在 `art/source/`，可直接用Blender打开。
