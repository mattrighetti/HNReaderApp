//
//  Item.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Foundation

/**
 Stories, comments, jobs, Ask HNs and even polls are just items. They're identified by their ids, which are unique integers.

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
struct Item: Decodable {
    let id: UUID
    let deleted: Bool?
    let type: ItemType?
    let by: String?
    let time: Int?
    let text: String?
    let dead: Bool?
    let parent: UUID?
    let poll: Bool?
    let kids: [UUID]?
    let url: String?
    let score: Int?
    let title: String?
    let parts: Int?
    let descendants: Int?
}

enum ItemType: String, Decodable {
    case poll = "poll"
    case job = "job"
    case story = "story"
    case comment = "comment"
    case pollopt = "pollopt"
}
