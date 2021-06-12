//
//  HackerNes.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Foundation

/// HackerNews endpoint data structure
struct HackerNews {
    public static let endpoint = "https://hacker-news.firebaseio.com/v0"

    /// HackerNews REST API methods
    enum API {
        /// HackerNews User REST API methods
        enum User {
            case id(String)
            
            public var urlString: String {
                switch self {
                case .id(let userId):
                    return "\(HackerNews.endpoint)/user/\(userId).json"
                }
            }
        }

        /// HackerNews Stories REST API methods
        enum Stories {
            case top
            case new
            case best
            
            public var urlString: String {
                switch self {
                case .top:
                    return "\(HackerNews.endpoint)/topstories.json"
                case .best:
                    return "\(HackerNews.endpoint)/beststories.json"
                case .new:
                    return "\(HackerNews.endpoint)/newstories.json"
                }
            }
        }

        /// HackerNews Item REST API methods
        enum Item {
            case id(Int)
            
            public var urlString: String {
                switch self {
                case .id(let storyId):
                    return "\(HackerNews.endpoint)/item/\(storyId).json"
                }
            }
        }
    }
}
