# AgentSafe Launcher

AgentSafe Launcher 是一个面向 Windows 小白用户的本地 AI Agent 权限分层启动器。

V1 原型目前只实现 `小绿` 模式：
- 默认工作区：`E:\安全终端`
- 通过隐藏本地账户启动受限终端
- 通过 `runas /savecred` 实现日常无感启动
- 重点保护主用户目录，降低本地命令行 Agent 的误操作范围

## 当前目录结构

```text
E:\AgentSafe\
├── modes\
│   └── xiaolv.json
├── scripts\
│   ├── setup.ps1
│   ├── launch.ps1
│   ├── diagnose.ps1
│   └── uninstall.ps1
└── README.md
```

## V1 范围

只支持：
- 小绿模式
- 命令行 Agent
- PowerShell 脚本式安装/启动/诊断/卸载

暂不支持：
- 小桃 / 柚子 / 爱丽丝 / 凯伊
- GUI
- VS Code / Cursor 整体受限启动
- 通用 ACL 规则引擎

## 使用流程

### 1. 首次配置

以管理员身份运行：

```powershell
powershell -ExecutionPolicy Bypass -File E:\AgentSafe\scripts\setup.ps1
```

脚本会：
- 创建并隐藏 `Agent_XiaoLv`
- 创建或确认 `E:\安全终端`
- 配置主用户目录拒绝访问和工作区可写 ACL
- 将凭据写入当前用户的凭据管理器
- 创建桌面快捷方式 `小绿安全终端.lnk`

### 2. 日常启动

双击桌面快捷方式，或运行：

```powershell
powershell -ExecutionPolicy Bypass -File E:\AgentSafe\scripts\launch.ps1
```

### 3. 诊断

```powershell
powershell -ExecutionPolicy Bypass -File E:\AgentSafe\scripts\diagnose.ps1
```

### 4. 卸载

以管理员身份运行：

```powershell
powershell -ExecutionPolicy Bypass -File E:\AgentSafe\scripts\uninstall.ps1
```

## 重要说明

- 这是一个原型版本，核心目标是验证“隐藏账户 + ACL + runas /savecred + 快捷方式”是否能稳定工作。
- 它防的是 AI Agent 的误操作，不是恶意软件攻击，也不是强沙箱。
- `runas /savecred` 在不同 Windows 环境中可能存在兼容性差异，V1 默认采用这条路径，后续可再优化。
- 当前 ACL 策略刻意保守，只重点保护工作区与主用户目录，不尝试在第一版里覆盖所有系统路径细节。
