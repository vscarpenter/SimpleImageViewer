import AppKit
final class ProbeDelegate: NSObject, NSWindowDelegate {
    deinit { print("delegate deinitialized") }
}
weak var weakDelegate: ProbeDelegate?
let window = NSWindow()
func attach() {
    autoreleasepool {
        let temporary = ProbeDelegate()
        weakDelegate = temporary
        window.delegate = temporary
        print("inside helper delegate present:", window.delegate != nil)
    }
}
attach()
print("after autoreleasepool weak delegate present:", weakDelegate != nil)
RunLoop.current.run(until: Date().addingTimeInterval(0.01))
print("after runloop weak delegate present:", weakDelegate != nil)
print("after runloop window delegate present:", window.delegate != nil)
