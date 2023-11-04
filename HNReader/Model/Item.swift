//
//  Item.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Foundation

/**
 Stories, comments, jobs, Ask HNs and even polls are items. They're identified by their ids, which are unique integers.

 For example, a story: https://hacker-news.firebaseio.com/v0/item/8863.json?print=pretty
 ```json
 {
   "by" : "dhouston",
   "descendants" : 71,
   "id" : 8863,
   "kids" : [ 8952, 9224, 8917, 8884, 8887, 8943, 8869, 8958, 9005, 9671, 8940, 9067, 8908, 9055, 8865, 8881, 8872, 8873, 8955, 10403, 8903, 8928, 9125, 8998, 8901, 8902, 8907, 8894, 8878, 8870, 8980, 8934, 8876 ],
   "score" : 111,
   "time" : 1175714200,
   "title" : "My YC app: Dropbox - Throw away your USB drive",
   "type" : "story",
   "url" : "http://www.getdropbox.com/u/2/screencast.html"
 }
 ```
 */
public struct Item: Decodable {
    public let id: Int
    public let deleted: Bool?
    public let type: ItemType?
    public let by: String?
    public let time: Int?
    public let text: String?
    public let dead: Bool?
    public let parent: Int?
    public let poll: Bool?
    public let kids: [Int]?
    public let url: String?
    public let score: Int?
    public let title: String?
    public let parts: Int?
    public let descendants: Int?
    
    public var urlHost: String? {
        if let url = url {
            var hostString = URL(string: url)!.host!
            if hostString.contains("www.") {
                hostString.removeFirst(4)
            }
            return hostString
        } else {
            return nil
        }
    }

    public var scoreString: String? {
        guard let score = score else { return nil }
        return "\(score)"
    }

    public var timeStringRepresentation: String? {
        Date().timeElapsedStringRepresentation(since: Date(timeIntervalSince1970: TimeInterval(time!)))
    }
}

public enum ItemType: String, Decodable {
    case poll
    case job
    case story
    case comment
    case pollopt
}
