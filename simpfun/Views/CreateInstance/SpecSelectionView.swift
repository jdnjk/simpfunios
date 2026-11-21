//
//  SpecSelectionView.swift
//  simpfun
//

import SwiftUI

struct SpecSelectionView: View {
    let mirror: MirrorType
    let version: GameVersion

    @Environment(AppModel.self) private var model
    @State private var items: [ShopItem] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private var sections: [GradeSection] {
        Dictionary(grouping: items) { $0.areaGrade }
            .map { grade, items in
                GradeSection(
                    grade: grade,
                    items: items.sorted { lhs, rhs in
                        if lhs.point == rhs.point {
                            return lhs.id < rhs.id
                        }
                        return lhs.point < rhs.point
                    }
                )
            }
            .sorted { lhs, rhs in
                let lhsRank = gradeRank(lhs.grade)
                let rhsRank = gradeRank(rhs.grade)
                if lhsRank == rhsRank {
                    return lhs.grade < rhs.grade
                }
                return lhsRank < rhsRank
            }
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        if item.creatable {
                            NavigationLink(value: CreateInstanceStep.confirmation(mirror, version, item)) {
                                row(item)
                            }
                        } else {
                            row(item)
                        }
                    }
                } header: {
                    Text(verbatim: "区域等级 \(section.grade)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if items.isEmpty {
                ListStateView(
                    isLoading: isLoading,
                    hasLoaded: hasLoaded,
                    errorMessage: errorMessage,
                    emptyTitle: "暂无规格",
                    emptyDescription: "该版本暂时没有可用的实例规格。"
                ) {
                    Task { await load(force: true) }
                }
            }
        }
        .navigationTitle("选择规格")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func row(_ item: ShopItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.displayCode)
                    .font(.headline)
                    .monospacedDigit()

                Spacer(minLength: 12)

                Text(verbatim: "\(item.point) 积分")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(verbatim: "\(item.cpu) 核 · \(item.ram) GB 内存 · \(item.disk) GB 存储 · \(item.traffic) GB 流量")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !item.creatable {
                Text("暂不可创建")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    /// 等级权重：S+ > S > A > B++ > B+ > C+。陈列时按权重升序，低等级在前。
    private func gradeRank(_ grade: String) -> Int {
        let upper = grade.uppercased()
        let base: Int
        switch upper.first {
        case "S":
            base = 50
        case "A":
            base = 40
        case "B":
            base = 30
        case "C":
            base = 20
        case "D":
            base = 10
        default:
            base = 0
        }
        return base + upper.filter { $0 == "+" }.count
    }

    private func load(force: Bool = false) async {
        guard (force || !hasLoaded) && !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            items = try await model.loadShopItems(versionID: version.id, custom: mirror.isCustom)
            errorMessage = nil
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GradeSection: Identifiable {
    let grade: String
    let items: [ShopItem]

    var id: String { grade }
}
