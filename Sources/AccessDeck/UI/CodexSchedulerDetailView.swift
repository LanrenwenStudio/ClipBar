import SwiftUI

struct CodexSchedulerDetailView: View {
    @Environment(AppModel.self) private var model
    #if os(macOS)
    @Environment(\.dismiss) private var dismiss
    #else
    @Environment(\.dismiss) private var dismiss
    #endif

    init() {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    healthHeaderCard
                    accountsPlanSection
                    attemptsSection
                    rulesNoticeCard
                }
                .padding(14)
            }
            .navigationTitle(L10n.t("Plus 额度智能调度", "Plus Quota Scheduler"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("完成", "Done")) {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task { await model.refreshCodexScheduler() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .disabled(model.isSchedulerLoading)
                    .help(L10n.t("刷新调度状态", "Refresh scheduler status"))
                }
            }
            .task {
                if model.codexSchedulerStatus == nil {
                    await model.refreshCodexScheduler()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 420, maxWidth: 480, minHeight: 460, idealHeight: 520, maxHeight: 620)
        #endif
    }

    // MARK: - 1. 健康状态与规划概要
    private var healthHeaderCard: some View {
        let status = model.codexSchedulerStatus
        let isStale = status?.isStale ?? true
        let hasData = status != nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(hasData ? (isStale ? AccessDeckTheme.warning : AccessDeckTheme.success) : Color.secondary)
                    .frame(width: 9, height: 9)

                Text(hasData ? (isStale ? L10n.t("采样延迟 (>45m)", "Stale (>45m)") : L10n.t("调度运行中", "Scheduler Active")) : L10n.t("未连接调度服务", "Scheduler Offline"))
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                if status?.plan != nil {
                    Text(status?.isPlanFromToday == true ? L10n.t("今日计划", "Today's Plan") : L10n.t("沿用旧计划", "Using Fallback"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(status?.isPlanFromToday == true ? AccessDeckTheme.accent : AccessDeckTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (status?.isPlanFromToday == true ? AccessDeckTheme.accent : AccessDeckTheme.warning).opacity(0.12),
                            in: Capsule()
                        )
                }
            }

            Divider().opacity(0.5)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("最新采样", "Latest Sample"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(status?.formattedLatestSampleTime ?? "--")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("样本总数", "Total Samples"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(status?.samplesCount ?? 0) " + L10n.t("条 (30天)", "pts"))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("今日 AI 规划", "Daily AI Planning"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    let latestPlanning = status?.planning.last
                    Text(latestPlanning?.localizedStatus ?? L10n.t("尚未执行", "Not yet"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(latestPlanning?.status == "completed" ? AccessDeckTheme.success : Color.primary)
                }
            }

            if let error = model.schedulerError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 10))
                }
                .foregroundStyle(AccessDeckTheme.danger)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }

    // MARK: - 2. 账号计划与额度详情
    private var accountsPlanSection: some View {
        let status = model.codexSchedulerStatus
        let plan = status?.plan
        let accounts = plan?.accounts ?? []

        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("Codex Plus 账号计划", "Codex Plus Accounts"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            if accounts.isEmpty {
                Text(L10n.t("暂无计划数据", "No plan data"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in
                    accountPlanCard(acc: acc, index: index + 1, status: status)
                }
            }
        }
    }

    private func accountPlanCard(acc: SchedulerAccountPlan, index: Int, status: CodexSchedulerStatus?) -> some View {
        let sample = status?.latestSamples.first { $0.account == acc.account }
        let primaryUsed = sample?.quota?.primary?.used
        let weeklyUsed = sample?.quota?.weekly?.used
        let resetTime = sample?.quota?.primary?.formattedResetTime ?? "--"

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AccessDeckTheme.brandColor(for: .codex))
                    Text(L10n.t("账号 \(index) (\(acc.shortAccountID))", "Account \(index) (\(acc.shortAccountID))"))
                        .font(.system(size: 12.5, weight: .bold))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(L10n.t("唤醒时点：", "Times: "))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text(acc.timesSummary)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AccessDeckTheme.accent)
                }
            }

            if sample?.quota != nil {
                HStack(spacing: 12) {
                    quotaMetric(label: L10n.t("5h 已用", "5h Used"), value: primaryUsed)
                    quotaMetric(label: L10n.t("周已用", "Week Used"), value: weeklyUsed)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.t("5h 重置", "Reset"))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(resetTime)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
                .padding(.vertical, 2)
            } else if let error = sample?.error {
                Text(L10n.t("额度未知：\(error)", "Quota unknown: \(error)"))
                    .font(.system(size: 10))
                    .foregroundStyle(AccessDeckTheme.warning)
            }

            if let reason = acc.reason, !reason.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("AI 规划理由：", "AI Reasoning:"))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(reason)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }

    private func quotaMetric(label: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            if let val = value {
                Text("\(Int(val.rounded()))%")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(val >= 100 ? AccessDeckTheme.danger : (val >= 80 ? AccessDeckTheme.warning : Color.primary))
            } else {
                Text("--")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 3. 今日处理与唤醒记录
    private var attemptsSection: some View {
        let attempts = model.codexSchedulerStatus?.attempts ?? []

        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("今日时点执行记录", "Today's Execution Log"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            if attempts.isEmpty {
                Text(L10n.t("今日暂无执行记录（计划时点未到或未触发）", "No execution records yet today."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(16)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 6) {
                    ForEach(attempts.reversed()) { att in
                        attemptRow(att: att)
                    }
                }
            }
        }
    }

    private func attemptRow(att: SchedulerAttempt) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(att.formattedTime)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("(\(att.shortAccountID))")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))

            statusBadge(status: att.status, label: att.localizedStatus)

            Text(att.localizedReason)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            if let err = att.error {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AccessDeckTheme.danger)
                    .help(err)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func statusBadge(status: String, label: String) -> some View {
        let color: Color
        switch status {
        case "completed": color = AccessDeckTheme.success
        case "skipped": color = Color.secondary
        case "failed": color = AccessDeckTheme.danger
        default: color = AccessDeckTheme.accent
        }

        return Text(label)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - 4. 关键规则说明卡片
    private var rulesNoticeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10.5))
                Text(L10n.t("调度机制说明", "Scheduler Directives"))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            Text(L10n.t(
                "• 半小时采样：每 30 分钟采集一次上游真实用量，超过 45 分钟未采样视为滞后。\n• 每日规划：每日 04:00 后首次运行由 AI 分析过去 7 天负载规划当天时点，失败则沿用前次计划。\n• 窗口唤醒：在计划时点到达且窗口空闲时发送单次最小测试请求尝试开启五小时窗口；已有活跃窗口、额度耗尽或四小时内调用过时自动跳过，绝不强制刷新额度。",
                "• Sampled every 30m; flagged stale if >45m.\n• Planned by AI once daily after 04:00 CST; falls back if failed.\n• Wake-ups send a minimal request only when a window is idle. Active/exhausted windows are skipped; never forces quota reset."
            ))
            .font(.system(size: 9.5))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var cardBackground: some View {
        #if os(macOS)
        Color.primary.opacity(0.035)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}
