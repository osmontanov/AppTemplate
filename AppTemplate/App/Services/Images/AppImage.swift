#if canImport(UIKit)
import UIKit

typealias AppImage = UIImage
#else
import AppKit

typealias AppImage = NSImage
#endif
