# Local EventBus Only Communication

## Purpose

定义 MaterialClient 全项目事件通信统一使用 ABP `ILocalEventBus` 的约束与验收标准，禁止运行时代码依赖 ReactiveUI MessageBus 或 EventBus→MessageBus 桥接。

## Requirements
