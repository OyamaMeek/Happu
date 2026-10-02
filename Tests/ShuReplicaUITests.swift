import XCTest

final class ShuReplicaUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testArchiveMenusNamingProgressAndPassword() {
        let app = startApplication()
        app.tabBars.buttons["文件"].tap()
        app.buttons["所有文件"].tap()
        let folderName = "归档测试-\(UUID().uuidString.prefix(6))"
        app.buttons["新增"].tap()
        app.buttons["新建文件夹"].tap()
        app.alerts.textFields["名称"].typeText(folderName)
        app.alerts.buttons["保存"].tap()
        let folder = app.buttons[folderName]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        folder.press(forDuration: 1)
        XCTAssertTrue(app.buttons["打包为 ZIP"].waitForExistence(timeout: 5))
        app.buttons["打包为 ZIP"].tap()
        XCTAssertTrue(app.textFields["ZIP 名称"].waitForExistence(timeout: 5))
        app.buttons["关闭"].tap()

        app.buttons["编辑"].tap()
        folder.tap()
        app.buttons["批量操作"].tap()
        app.buttons["打包为 ZIP"].tap()
        XCTAssertTrue(app.textFields["ZIP 名称"].waitForExistence(timeout: 5))
        app.buttons["开始打包"].tap()
        XCTAssertTrue(app.staticTexts["归档进度"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["处理完成"].waitForExistence(timeout: 15))
        app.buttons["关闭"].tap()
        app.buttons["完成"].tap()

        let archive = fileRow(app, folderName + ".zip")
        reveal(archive, in: app)
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        archive.press(forDuration: 1)
        XCTAssertTrue(app.buttons["解压"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["解压到…"].exists)
        app.buttons["解压"].tap()
        let password = app.secureTextFields["密码（普通 ZIP 可留空）"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("输入测试")
        app.buttons["关闭"].tap()
        archive.press(forDuration: 1)
        app.buttons["解压到…"].tap()
        XCTAssertTrue(app.buttons["解压到这里"].waitForExistence(timeout: 5))
        app.buttons["解压到这里"].tap()
        XCTAssertTrue(app.buttons["开始解压"].waitForExistence(timeout: 5))
    }

    func testTabsFolderNavigationAndSelection() {
        let app = startApplication()

        app.tabBars.buttons["下载"].tap()
        XCTAssertTrue(app.navigationBars["下载"].waitForExistence(timeout: 5))
        app.tabBars.buttons["更多"].tap()
        XCTAssertTrue(app.navigationBars["更多"].waitForExistence(timeout: 5))
        app.tabBars.buttons["文件"].tap()
        app.buttons["所有文件"].tap()

        let folderName = "交互测试-\(UUID().uuidString.prefix(6))"
        app.buttons["新增"].tap()
        app.buttons["新建文件夹"].tap()
        let name = app.alerts.textFields["名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(folderName)
        app.alerts.buttons["保存"].tap()

        app.buttons["编辑"].tap()
        print("SELECTION MENU STATE: \(app.debugDescription)")
        XCTAssertTrue(app.buttons["选择"].isHittable)
        app.buttons["选择"].tap()
        XCTAssertTrue(app.buttons["全选"].waitForExistence(timeout: 5))
        app.buttons["全选"].tap()
        XCTAssertEqual(app.buttons[folderName].value as? String, "已选择")
        let count = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已选 ")).firstMatch
        let selectedCount = count.label
        let search = app.searchFields.firstMatch
        if !search.exists { app.swipeDown() }
        print("SEARCH ACTIVATION STATE: \(app.debugDescription)")
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(folderName)
        XCTAssertEqual(count.label, selectedCount)
        XCTAssertEqual(search.value as? String, folderName)
        XCTAssertFalse(app.buttons["Downloads"].exists)
        XCTAssertTrue(app.keyboards.buttons["Search"].isHittable)
        app.keyboards.buttons["Search"].tap()
        let keyboardHidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        let submitted = XCTWaiter.wait(for: [keyboardHidden], timeout: 10)
        if submitted != .completed { print("SEARCH SUBMIT STATE: \(app.debugDescription)") }
        XCTAssertEqual(submitted, .completed)
        XCTAssertEqual(search.value as? String, folderName)
        XCTAssertEqual(count.label, selectedCount)
        XCTAssertFalse(app.buttons["Downloads"].exists)
        let originalCount = Int(selectedCount.split(separator: " ")[1])!
        XCTAssertTrue(app.buttons["选择"].isHittable)
        app.buttons["选择"].tap()
        app.buttons["反选"].tap()
        XCTAssertEqual(app.buttons[folderName].value as? String, "未选择")
        XCTAssertNotEqual(count.label, selectedCount)
        XCTAssertEqual(count.label, "已选 \(originalCount - 1) 项")
        XCTAssertEqual(search.value as? String, folderName)
        app.buttons["选择"].tap()
        XCTAssertTrue(app.buttons["取消选择"].waitForExistence(timeout: 5))
        app.buttons["取消选择"].tap()
        XCTAssertEqual(count.label, "已选 0 项")
        app.buttons["关闭"].tap()
        app.buttons["完成"].tap()
        XCTAssertTrue(app.tabBars.buttons["下载"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["下载"].isHittable)
        app.tabBars.buttons["下载"].tap()
        XCTAssertTrue(app.navigationBars["下载"].waitForExistence(timeout: 5))
        app.tabBars.buttons["文件"].tap()
        app.buttons[folderName].tap()
        XCTAssertTrue(app.navigationBars[folderName].waitForExistence(timeout: 5))
    }

    func testDocumentPDFOperations() {
        let app = workspace("PDFs")
        app.navigationBars["PDFs"].buttons.matching(identifier: "编辑").element.tap()
        fileRow(app, "a.pdf").tap()
        XCTAssertEqual(fileRow(app, "a.pdf").value as? String, "已选择")
        fileRow(app, "locked.pdf").tap()
        XCTAssertEqual(fileRow(app, "locked.pdf").value as? String, "已选择")
        XCTAssertTrue(app.staticTexts["已选 2 项"].exists)
        if !app.buttons["批量操作"].isHittable { print("PDF BATCH ACTION STATE: \(app.debugDescription)") }
        XCTAssertTrue(app.buttons["批量操作"].isHittable)
        app.buttons["批量操作"].tap()
        XCTAssertTrue(app.buttons["合并 PDF"].waitForExistence(timeout: 5))
        app.buttons["合并 PDF"].tap()
        XCTAssertTrue(app.navigationBars["PDF 处理"].waitForExistence(timeout: 5))
        app.buttons["上移 locked.pdf"].tap()
        app.buttons["下移 locked.pdf"].tap()
        app.buttons["上移 locked.pdf"].tap()
        enter(app.secureTextFields["密码 locked.pdf"], "secret")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-merged")
        complete(app)
        XCTAssertTrue(app.buttons["预览结果"].exists)
        XCTAssertTrue(app.buttons["分享结果"].exists)
        app.buttons["预览结果"].tap()
        closePreview(app)
        let documentClose = app.navigationBars["PDF 处理"].buttons["关闭"]
        let returned = NSPredicate { _, _ in documentClose.isHittable && app.buttons["分享结果"].isHittable }
        let returnResult = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: returned, object: nil)], timeout: 10)
        if returnResult != .completed { print("PREVIEW RETURN STATE: \(app.debugDescription)") }
        XCTAssertEqual(returnResult, .completed)
        app.buttons["分享结果"].tap()
        print("SYSTEM SHARE STATE: \(app.debugDescription)")
        let covered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == false"), object: documentClose)
        XCTAssertEqual(XCTWaiter.wait(for: [covered], timeout: 10), .completed)
        closeSystemShare(app)
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: documentClose)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        documentClose.tap()
        app.buttons["完成"].tap()

        openDocument(app, file: "a.pdf", menu: "PDF 处理")
        operation(app, "分割 PDF")
        enter(app.textFields["每份页数"], "2")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-split")
        complete(app)
        app.buttons["关闭"].tap()
        openDocument(app, file: "b.pdf", menu: "PDF 处理")
        operation(app, "按页导出")
        enter(app.textFields["分辨率 dpi"], "144")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-pages")
        complete(app)
        app.buttons["关闭"].tap()

        openDocument(app, file: "locked.pdf", menu: "PDF 处理")
        operation(app, "移除密码")
        enter(app.secureTextFields["密码 locked.pdf"], "secret")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-unlocked")
        complete(app)
        app.buttons["关闭"].tap()
    }

    func testDocumentImageOperations() {
        let app = workspace("Images")
        openDocument(app, file: "red.png", menu: "图片处理")
        app.buttons["图片格式"].tap()
        app.buttons["JPEG"].tap()
        enter(app.textFields["图片质量"], "0.6")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-quality")
        complete(app)
        app.buttons["关闭"].tap()

        openDocument(app, file: "animation.gif", menu: "图片处理")
        enter(app.textFields["帧序号（从零开始，可留空）"], "1")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-frame")
        complete(app)
        app.buttons["关闭"].tap()
        openDocument(app, file: "animation.gif", menu: "图片处理")
        operation(app, "提取全部帧")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-frames")
        complete(app)
        app.buttons["关闭"].tap()

        app.navigationBars["Images"].buttons.matching(identifier: "编辑").element.tap()
        fileRow(app, "red.png").tap()
        XCTAssertEqual(fileRow(app, "red.png").value as? String, "已选择")
        fileRow(app, "blue.png").tap()
        XCTAssertEqual(fileRow(app, "blue.png").value as? String, "已选择")
        XCTAssertTrue(app.staticTexts["已选 2 项"].exists)
        if !app.buttons["批量操作"].isHittable { print("IMAGE BATCH ACTION STATE: \(app.debugDescription)") }
        XCTAssertTrue(app.buttons["批量操作"].isHittable)
        app.buttons["批量操作"].tap()
        XCTAssertTrue(app.buttons["合成图片"].waitForExistence(timeout: 5))
        app.buttons["合成图片"].tap()
        app.buttons["下移 blue.png"].tap()
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-composed")
        complete(app)
        app.buttons["关闭"].tap()
        app.buttons["完成"].tap()
    }

    func testDocumentCancellationAndRetry() {
        let app = workspace("PDFs")
        openDocument(app, file: "locked.pdf", menu: "PDF 处理")
        operation(app, "移除密码")
        enter(app.secureTextFields["密码 locked.pdf"], "wrong")
        app.buttons["开始处理"].tap()
        XCTAssertTrue(app.staticTexts["处理失败"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["PDF 密码缺失或不正确。"].exists)
        app.buttons["返回输入重试"].tap()
        enter(app.secureTextFields["密码 locked.pdf"], "secret")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-retry")
        complete(app)
        app.buttons["关闭"].tap()

        openDocument(app, file: "cancel.pdf", menu: "PDF 处理")
        operation(app, "按页导出")
        enter(app.textFields["分辨率 dpi"], "300")
        enter(app.textFields["输出名称"], "ui-cancelled")
        app.buttons["开始处理"].tap()
        XCTAssertTrue(app.buttons["取消处理"].waitForExistence(timeout: 10))
        let processed = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "已处理 [1-9][0-9]* / 600 项")).firstMatch
        XCTAssertTrue(processed.waitForExistence(timeout: 30))
        let progressText = processed.label
        let updated = NSPredicate(format: "label != %@", progressText)
        expectation(for: updated, evaluatedWith: processed)
        waitForExpectations(timeout: 30)
        app.buttons["取消处理"].tap()
        XCTAssertTrue(app.staticTexts["已取消"].waitForExistence(timeout: 60))
        app.buttons["关闭"].tap()
        XCTAssertFalse(app.buttons["ui-cancelled"].exists)
        openDocument(app, file: "cancel.pdf", menu: "PDF 处理")
        operation(app, "按页导出")
        enter(app.textFields["分辨率 dpi"], "300")
        enter(app.textFields["输出名称"], "ui-close-cancelled")
        app.buttons["开始处理"].tap()
        XCTAssertTrue(app.buttons["取消处理"].waitForExistence(timeout: 10))
        app.buttons["关闭"].tap()
        XCTAssertTrue(fileRow(app, "cancel.pdf").waitForExistence(timeout: 60))
        openDocument(app, file: "a.pdf", menu: "PDF 处理")
        XCTAssertTrue(app.buttons["开始处理"].waitForExistence(timeout: 5))
        app.buttons["关闭"].tap()

        app.tabBars.buttons["更多"].tap()
        app.buttons["PDF 处理"].tap()
        cancelImporter(app)
        XCTAssertTrue(app.navigationBars["更多"].waitForExistence(timeout: 5))
        app.buttons["图片转换"].tap()
        cancelImporter(app)
        XCTAssertTrue(app.navigationBars["更多"].waitForExistence(timeout: 5))
    }

    func testMoreDocumentImportFromFiles() {
        let app = startApplication()
        app.tabBars.buttons["更多"].tap()
        app.buttons["PDF 处理"].tap()
        waitForImporter(app)
        print("SYSTEM SELECT IMPORT STATE: \(app.debugDescription)")
        let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["浏览", "Browse"])).firstMatch
        if browse.exists && !browse.isSelected { browse.tap() }
        print("SYSTEM BROWSE LOCATIONS STATE: \(app.debugDescription)")
        let fileView = app.collectionViews["File View"]
        XCTAssertTrue(fileView.waitForExistence(timeout: 10))
        let appFolder = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Shu Replica,")).firstMatch
        for _ in 0..<6 {
            if appFolder.exists && appFolder.isHittable { break }
            let back = app.buttons["DOC.navBarButton.backInHistory"]
            XCTAssertTrue(back.isHittable && back.isEnabled)
            back.tap()
        }
        XCTAssertTrue(appFolder.exists && appFolder.isHittable)
        let inputFolder = fileView.cells["DocumentUITests, Folder"]
        reveal(inputFolder, in: app, list: fileView)
        inputFolder.tap()
        XCTAssertTrue(fileView.cells["PDFs, Folder"].waitForExistence(timeout: 10))
        fileView.cells["PDFs, Folder"].tap()
        let file = fileView.cells["b, pdf"]
        XCTAssertTrue(file.waitForExistence(timeout: 10))
        XCTAssertTrue(file.isHittable)
        file.tap()
        print("SYSTEM SELECTED FILE STATE: \(app.debugDescription)")
        let open = app.buttons.matching(NSPredicate(format: "label IN %@", ["打开", "Open"])).firstMatch
        if open.exists { open.tap() }
        XCTAssertTrue(app.navigationBars["PDF 处理"].waitForExistence(timeout: 30))
        operation(app, "按页导出")
        chooseOutput(app)
        enter(app.textFields["输出名称"], "ui-imported-pages")
        complete(app)
        app.buttons["关闭"].tap()
        app.tabBars.buttons["文件"].tap()
        app.buttons["所有文件"].tap()
        let imported = fileRow(app, "b.pdf")
        reveal(imported, in: app)
        XCTAssertTrue(imported.waitForExistence(timeout: 10))
    }

    private func workspace(_ folder: String) -> XCUIApplication {
        let app = startApplication()
        app.tabBars.buttons["文件"].tap()
        app.buttons["所有文件"].tap()
        reveal(app.buttons["DocumentUITests"], in: app)
        XCTAssertTrue(app.buttons["DocumentUITests"].waitForExistence(timeout: 10))
        app.buttons["DocumentUITests"].tap()
        app.buttons[folder].tap()
        let bars = app.navigationBars.matching(identifier: folder)
        let ready = NSPredicate { _, _ in
            guard bars.count == 1 else { return false }
            let edit = bars.element.buttons.matching(identifier: "编辑")
            return edit.count == 1 && edit.element.isHittable
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 10)
        if result != .completed { print("WORKSPACE NAVIGATION STATE: \(app.debugDescription)") }
        XCTAssertEqual(result, .completed)
        return app
    }

    private func startApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.activate()
        if app.otherElements["PopoverDismissRegion"].isHittable { closeSystemShare(app) }
        if app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"].isHittable { closePreview(app) }
        if app.staticTexts["处理失败"].exists { print("PREVIOUS OPERATION ERROR: \(app.debugDescription)") }
        if app.buttons["取消处理"].isHittable {
            if app.buttons["取消处理"].isEnabled { app.buttons["取消处理"].tap() }
            XCTAssertTrue(app.staticTexts["已取消"].waitForExistence(timeout: 60))
        }
        if app.buttons["保存到这里"].exists {
            print("PREVIOUS DESTINATION STATE: \(app.debugDescription)")
            tapDestination(app)
        }
        let nativeCancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
        if nativeCancel.isHittable { nativeCancel.tap() }
        if app.buttons["关闭"].isHittable { app.buttons["关闭"].tap() }
        if app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已选 ")).firstMatch.exists,
           app.buttons["完成"].isHittable {
            print("PREVIOUS SELECTION STATE: \(app.debugDescription)")
            app.buttons["完成"].tap()
        }
        app.tabBars.buttons["文件"].tap()
        app.navigationBars.firstMatch.tap()
        for _ in 0..<4 {
            if app.buttons["所有文件"].exists { break }
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.buttons["所有文件"].waitForExistence(timeout: 5))
        return app
    }

    private func cancelImporter(_ app: XCUIApplication) {
        waitForImporter(app)
        print("SYSTEM IMPORT STATE: \(app.debugDescription)")
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
    }

    private func closePreview(_ app: XCUIApplication) {
        let close = app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let ready = NSPredicate { _, _ in app.otherElements["QLPDFViewControllerViewAccessibilityIdentifier"].exists && close.isHittable }
        let readyResult = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 10)
        if readyResult != .completed { print("PREVIEW READY STATE: \(app.debugDescription)") }
        XCTAssertEqual(readyResult, .completed)
        close.tap()
        let dismissed = NSPredicate { _, _ in !app.otherElements["QLPreviewControllerView"].exists && !close.exists }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: dismissed, object: nil)], timeout: 10)
        if result != .completed { print("PREVIEW DISMISS STATE: \(app.debugDescription)") }
        XCTAssertEqual(result, .completed)
    }

    private func closeSystemShare(_ app: XCUIApplication) {
        let owner = XCUIApplication(bundleIdentifier: "com.apple.SharingUIService")
        let presented = owner.collectionViews["activityCollectionView"].waitForExistence(timeout: 10)
        print("SYSTEM SHARE OWNER: \(owner.debugDescription)")
        print("SYSTEM SHARE FOREGROUND: \(app.debugDescription)")
        XCTAssertTrue(presented)
        XCTAssertTrue(owner.otherElements["LP.CaptionBar.TopCaption"].exists)
        let dismiss = app.otherElements.matching(identifier: "PopoverDismissRegion")
        XCTAssertEqual(dismiss.count, 1)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: dismiss.element)
        let readyResult = XCTWaiter.wait(for: [ready], timeout: 10)
        if readyResult != .completed { print("SYSTEM SHARE DISMISS READY STATE: \(app.debugDescription)") }
        XCTAssertEqual(readyResult, .completed)
        dismiss.element.tap()
        let closed = NSPredicate { _, _ in app.popovers.count == 0 && !owner.collectionViews["activityCollectionView"].exists }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: closed, object: nil)], timeout: 10)
        if result != .completed { print("SYSTEM SHARE DISMISS STATE: \(app.debugDescription)") }
        XCTAssertEqual(result, .completed)
    }

    private func waitForImporter(_ app: XCUIApplication) {
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
        let presented = cancel.waitForExistence(timeout: 60)
        if !presented {
            print("IMPORT PRESENTATION FAILURE: \(app.debugDescription)")
            print("SYSTEM FOREGROUND STATE: \(XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription)")
        }
        XCTAssertTrue(presented)
        XCTAssertTrue(cancel.isHittable)
    }

    private func openDocument(_ app: XCUIApplication, file: String, menu: String) {
        let input = fileRow(app, file)
        if !input.exists { print("DOCUMENT INPUT STATE: \(app.debugDescription)") }
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.press(forDuration: 1)
        XCTAssertTrue(app.buttons[menu].waitForExistence(timeout: 5))
        app.buttons[menu].tap()
    }

    private func fileRow(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func operation(_ app: XCUIApplication, _ title: String) {
        app.buttons["操作类型"].tap()
        app.buttons[title].tap()
    }

    private func enter(_ field: XCUIElement, _ value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let app = XCUIApplication()
        let keyboard = app.keyboards.firstMatch
        let focused = keyboard.waitForExistence(timeout: 45)
        if !focused { print("INPUT FOCUS FAILURE: \(app.debugDescription)") }
        XCTAssertTrue(focused)
        if let text = field.value as? String, !text.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
        }
        field.typeText(value + "\n")
    }

    private func chooseOutput(_ app: XCUIApplication) {
        app.buttons["选择目的目录…"].tap()
        XCTAssertTrue(app.buttons["保存到这里"].waitForExistence(timeout: 10))
        print("DESTINATION PICKER STATE: \(app.debugDescription)")
        let folder = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "DocumentUITests", "BackButton")).firstMatch
        reveal(folder, in: app, list: app.collectionViews["destination-folders"])
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        XCTAssertTrue(folder.isHittable)
        folder.tap()
        XCTAssertTrue(app.buttons["Output"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Output"].isHittable)
        app.buttons["Output"].tap()
        print("DESTINATION OUTPUT STATE: \(app.debugDescription)")
        tapDestination(app)
    }

    private func tapDestination(_ app: XCUIApplication) {
        let buttons = app.buttons.matching(identifier: "保存到这里")
        let visible = NSPredicate { _, _ in buttons.allElementsBoundByIndex.contains { $0.isHittable } }
        let expectation = XCTNSPredicateExpectation(predicate: visible, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: 30)
        if result != .completed { print("DESTINATION ACTION FAILURE: \(app.debugDescription)") }
        XCTAssertEqual(result, .completed)
        guard let button = buttons.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("目的目录保存按钮不可点击")
            return
        }
        button.tap()
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, list: XCUIElement? = nil) {
        let list = list ?? app.collectionViews["workspace-files"]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: list)
        let result = XCTWaiter.wait(for: [visible], timeout: 10)
        guard result == .completed else {
            print("VISIBLE LIST FAILURE: \(app.debugDescription)")
            XCTFail("前台文件列表不可点击")
            return
        }
        if element.exists && element.isHittable { return }
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            list.swipeUp()
        }
        print("FILE REVEAL FAILURE: \(app.debugDescription)")
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func complete(_ app: XCUIApplication) {
        app.buttons["开始处理"].tap()
        XCTAssertTrue(app.staticTexts["文档进度"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["处理完成"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["document-output"].exists)
    }
}
