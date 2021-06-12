//
//  User.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Foundation

public struct User: Decodable {
    public let id: String
    public let created: Int
    public let karma: Int
    public let about: String?
    public let submitted: [Int]?
}
