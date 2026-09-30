import XCTest

final class ShuReplicaUITests: XCTestCase {
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
        app.buttons["选择"].tap()
        XCTAssertTrue(app.buttons["取消选择"].waitForExistence(timeout: 5))
        app.buttons["取消选择"].tap()
        app.buttons["完成"].tap()
        app.buttons[folderName].tap()
        XCTAssertTrue(app.navigationBars[folderName].waitForExistence(timeout: 5))
    }
}
