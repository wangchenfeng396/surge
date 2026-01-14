# Xcode 项目清理指南

## 问题说明

已删除重复的模型文件，但 Xcode 项目文件 (.xcodeproj) 仍然引用这些已删除的文件，导致编译失败。

## 需要删除的文件引用

以下文件已从文件系统删除，需要在 Xcode 中移除引用：

❌ `Models/GeneralConfig.swift`
❌ `Models/ProxyConfig.swift`  
❌ `Models/ProxyGroup.swift`
❌ `Models/RuleModel.swift`
❌ `Services/LatencyMeasurement.swift`
❌ 根目录的 `ConfigModels.swift` (如果显示)

## 操作步骤

### 1. 打开 Xcode 项目

```bash
open /Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy/SurgeProxy.xcodeproj
```

### 2. 删除文件引用

在左侧 Project Navigator 中：
- 找到每个**红色**的文件名（表示文件丢失）
- 右键点击文件
- 选择 **"Delete"**
- 在弹出对话框中选择 **"Remove Reference"** （不是 Move to Trash）

### 3. 确认保留的文件

以下文件应该保持**正常显示**（不是红色）：
- ✅ `Models/ConfigModels.swift` - **新的统一模型文件**
- ✅ `Views/OverviewView.swift` - 包含 LatencyMeasurement 类

### 4. 清理并重新编译

```bash
# 方法 1: 使用 Xcode
# - 按 Cmd + Shift + K (Clean Build Folder)
# - 按 Cmd + B (Build)

# 方法 2: 使用命令行
cd /Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy
xcodebuild -scheme SurgeProxy clean
xcodebuild -scheme SurgeProxy -configuration Debug build
```

## 预期结果

清理完成后，编译应该成功，输出：

```
** BUILD SUCCEEDED **
```

## 如果还有红色文件

如果清理后还有其他红色文件：
1. 同样右键 → Delete → Remove Reference
2. 重复直到没有红色文件

## 下一步

编译成功后：
1. 运行 app: `Cmd + R`
2. 测试各项功能
3. 报告任何运行时错误

---

**提示**: 如果不确定某个红色文件是否应该删除，可以先不删，编译时会提示具体是哪些文件有问题。
