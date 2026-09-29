import SwiftUI

struct MoreView: View {
    @AppStorage("sortByDate") private var sortByDate = false

    var body: some View {
        Form {
            Section("文件") {
                Picker("文件排序", selection: $sortByDate) {
                    Text("名称").tag(false)
                    Text("最近修改").tag(true)
                }
            }
            Section("关于") {
                LabeledContent("应用", value: "Shu Replica")
                LabeledContent("原版参考", value: "Shu 1.2.4")
            }
        }
        .navigationTitle("更多")
    }
}
