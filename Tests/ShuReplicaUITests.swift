import XCTest

final class ShuReplicaUITests: XCTestCase {
    func testArchiveMenusNamingProgressAndPassword() {
        let app = XCUIApplication()
        app.launch()
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

        let archive = app.buttons[folderName + ".zip"]
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
        let app = XCUIApplication()
        app.launch()

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
        app.buttons["选择"].tap()
        XCTAssertTrue(app.buttons["全选"].waitForExistence(timeout: 5))
        app.buttons["全选"].tap()
        XCTAssertEqual(app.buttons[folderName].value as? String, "已选择")
        let count = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已选 ")).firstMatch
        let selectedCount = count.label
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText(folderName)
        XCTAssertEqual(count.label, selectedCount)
        app.buttons["选择"].tap()
        app.buttons["反选"].tap()
        XCTAssertEqual(app.buttons[folderName].value as? String, "未选择")
        XCTAssertNotEqual(count.label, selectedCount)
        app.buttons["选择"].tap()
        XCTAssertTrue(app.buttons["取消选择"].waitForExistence(timeout: 5))
        app.buttons["取消选择"].tap()
        app.buttons["完成"].tap()
        app.buttons[folderName].tap()
        XCTAssertTrue(app.navigationBars[folderName].waitForExistence(timeout: 5))
    }
}
