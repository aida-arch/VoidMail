import Foundation

/// Debug-only logger. Stripped from release builds via compiler flag.
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
