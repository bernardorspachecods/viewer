/// The zoom range shared by every document preview and the settings controls.
public enum DocumentZoomLimits {
    public static let minimum = 0.7
    public static let maximum = 2.0

    /// Clamps a zoom factor into `minimum...maximum`, keeping the value's type.
    public static func clamped<Value: BinaryFloatingPoint>(_ value: Value) -> Value {
        min(max(value, Value(minimum)), Value(maximum))
    }
}
