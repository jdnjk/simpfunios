//
//  MultipartFormData.swift
//  simpfun
//

import Foundation

/// 用于构造 `multipart/form-data` 请求体。
struct MultipartFormData {
    let boundary: String
    private var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func append(_ value: String, for name: String) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    func encoded() -> Data {
        var data = body
        data.append("--\(boundary)--\r\n")
        return data
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
