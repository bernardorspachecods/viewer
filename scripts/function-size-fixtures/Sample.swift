// Fixture for check-function-size.sh --self-test.
// Each body is measured from its keyword line to its closing brace.
import Foundation

struct Sample {
    var stored: Int
    var computed: Int {
        get { 1 }
        set { _ = newValue }
    }
    let text = """
    func notAFunction() {
    }
    """
    // func commentOnly() { }
    init(value: Int) {
        self.stored = value
    }
    func withBraces() -> String {
        let s = "{ } \"quoted\" \(stored > 0 ? "{" : "}")"
        return s // }
    }
    func nested() {
        func inner() {
            print("x")
        }
        inner()
    }
    protocol Requirement { func bodiless() }
    func afterBodiless() {
        _ = 1
    }
}
