# 阶段 4.5 完成总结 - 策略组正则过滤

## ✅ 完成目标

实现了策略组的 `policy-regex-filter` 过滤逻辑，并完成了配置集成。

### 核心变更

1.  **策略组增强 (`BaseGroup`)**
    *   在 `internal/policy/policy.go` 中，为 `BaseGroup` 增加了 `FilterRegex` 字段。
    *   实现了 `SetFilter(regex string)` 用于编译和设置过滤器。
    *   实现了 `FilterProxies(proxies []string)` 辅助方法，用于根据正则筛选节点列表。

2.  **策略组集成**
    *   更新了 `SelectGroup` (`internal/policy/select.go`) 和 `URLTestGroup` (`internal/policy/urltest.go`)，在 `UpdateProxies` 更新节点列表时自动应用过滤逻辑。

3.  **配置工厂 (`Factory`)**
    *   创建了 `internal/policy/factory.go`，实现了 `NewGroupFromConfig` 方法。
    *   该方法负责从 `ProxyGroupConfig` 创建具体的策略组实例，并根据 `policy_regex_filter` 字段自动应用过滤器，确保初始化的节点列表已被正确筛选。

### 📊 代码统计

*   **新增文件**:
    *   `internal/policy/factory.go`: 策略组去工厂方法。
    *   `internal/policy/filter_test.go`: 基础过滤逻辑单元测试。
    *   `internal/policy/factory_test.go`: 配置集成功能测试。
*   **修改文件**: `internal/policy/policy.go`, `internal/policy/select.go`, `internal/policy/urltest.go`.

### 🔍 验证说明

*   **单元测试**: `internal/policy/filter_test.go` 验证了正则匹配通过与否的基础逻辑。
    *   `TestBaseGroup_Filter`: 验证设置正则后，非匹配节点被正确排除。
*   **功能测试**: `internal/policy/factory_test.go` 模拟了从配置加载策略组的完整流程。
    *   `TestNewGroupFromConfig_SelectWithFilter`: 验证 Select 策略组在配置 regex 后，初始节点列表被正确过滤（4个节点 -> 2个匹配节点）。
    *   `TestNewGroupFromConfig_URLTestWithFilter`: 验证 URL-Test 策略组的过滤逻辑。
    *   `TestNewGroupFromConfig_InvalidRegex`: 验证非法正则会返回错误。

## 🚀 下一步

*   **Phase 4.6**: 策略组嵌套 (循环引用检测)。
*   **Phase 4.7**: `include-all-proxies` 支持。
