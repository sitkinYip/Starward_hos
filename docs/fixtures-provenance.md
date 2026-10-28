# 跨端响应夹具

由 scripts/export-web-fixtures.cjs 直接执行冻结 Web 的 mockStarwardApi 导出，Page.route 为无操作适配器，不打开浏览器、不访问网络、不改源仓库。

- Web commit: 4b7d1a0a00051ac630e459b0fd6c074f821d7455
- Source: e2e/fixtures.ts
- Source SHA-256: 632405ee6eedf8bd3d69c99f0dfe67c3c2e600c8236e8ba4b690512106b0f751
- Options: mustChange=true；其他保持默认。
- 唯一时间归一化：assignment.serverTime 固定 2026-10-27T00:00:00.000Z。
- 产物：entry/src/test/fixtures/WebFixture.ets（完整玩家与未开始场次响应，包括 question=null）。

原生只解码本切片需要的投影；未知字段保留在夹具但不宣称媒体/答题已迁移。该导出证明两端使用同一测试响应，不证明真实后端权限或网络。
