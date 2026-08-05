import Foundation

nonisolated
enum NetworkError: Error {
    case requestConstruction
    case requestEncoding(underlying: any Error)
    case requestAdaptation(underlying: any Error)
    case transport(underlying: any Error)
    case cancelled
    case nonHTTPResponse
    case unacceptableStatus(NetworkResponse)
    case decoding(underlying: any Error, response: NetworkResponse)
}
