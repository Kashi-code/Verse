import XCTest

/// Walks through the main screens on bundled sample data and attaches a screenshot of each.
/// CI exports them as the "Screenshots" artifact. It never fails on layout details.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData"]
        app.launch()

        _ = app.staticTexts["Trending Now"].waitForExistence(timeout: 20)
        pause(3)
        snapshot("01-Home", app)

        app.swipeUp()
        pause(2)
        snapshot("02-Home-Shelves", app)

        let playlist = app.buttons["playlist-card"].firstMatch
        var swipes = 0
        while !(playlist.exists && playlist.isHittable) && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        if playlist.exists && playlist.isHittable {
            playlist.tap()
            pause(4)
            snapshot("02b-Playlist-Page", app)
            app.swipeUp()
            pause(1)
            snapshot("02c-Playlist-Scrolled", app)
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
            pause(1)
        }
        for _ in 0..<8 { app.swipeDown() }

        let hero = app.buttons["trending-card"].firstMatch
        if hero.waitForExistence(timeout: 5) {
            hero.tap()
            pause(3)
            snapshot("03-Playing", app)

            let miniPlayer = app.buttons["mini-player"].firstMatch
            if miniPlayer.waitForExistence(timeout: 5) {
                miniPlayer.tap()
                pause(3)
                snapshot("04-Player", app)
                let lyrics = app.buttons["Lyrics"].firstMatch
                if lyrics.waitForExistence(timeout: 3) {
                    lyrics.tap()
                    pause(2)
                    snapshot("05-Player-Lyrics", app)
                }
                let close = app.buttons["Close"].firstMatch
                if close.waitForExistence(timeout: 3) { close.tap() }
                pause(1)
            }
        }

        let search = app.buttons["Search"].firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            pause(2)
            snapshot("06-Search", app)
            let field = app.searchFields.firstMatch
            if field.waitForExistence(timeout: 5) {
                field.tap()
                field.typeText("lofi")
                pause(4)
                snapshot("07-Search-Results", app)
            }
        }

        let library = app.buttons["Library"].firstMatch
        if library.waitForExistence(timeout: 5) {
            library.tap()
            pause(1)
            snapshot("08-Library", app)
        }
    }

    @MainActor
    private func snapshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
