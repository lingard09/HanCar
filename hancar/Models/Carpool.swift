//
//  Carpool.swift
//  hancar
//
//  Created by kinnwonjin on 12/11/25.
//
//  This model represents a single carpool entity.
//  It maps Firestore document data to a strongly typed Swift structure
//  and determines whether the current user has applied to the carpool.
//

import Foundation
import FirebaseFirestore

struct Carpool {
    let id: String
    let type: String
    let departure: String
    let destination: String
    let year: Int
    let date: String
    let time: String
    let currentCount: Int
    let maxCount: Int
    let notice: String
    let cost: String
    let creatorUid: String
    var isApplied: Bool
    
    // MARK: - Firestore Initialization
    init?(document: DocumentSnapshot, appliedCarpoolIDs: Set<String>) {
        let data = document.data()
        guard
            let data = data,
            let type = data["type"] as? String,
            let departure = data["departure"] as? String,
            let destination = data["destination"] as? String,
            let year = data["year"] as? Int,
            let date = data["date"] as? String,
            let time = data["time"] as? String,
            let currentCount = data["currentCount"] as? Int,
            let maxCount = data["maxCount"] as? Int,
            let notice = data["notice"] as? String,
            let cost = data["cost"] as? String,
            let creatorUid = data["creatorUid"] as? String
        else {
            return nil
        }

        self.id = document.documentID
        self.type = type
        self.departure = departure
        self.destination = destination
        self.year = year
        self.date = date
        self.time = time
        self.currentCount = currentCount
        self.maxCount = maxCount
        self.isApplied = appliedCarpoolIDs.contains(self.id)
        self.notice = notice
        self.cost = cost
        self.creatorUid = creatorUid
    }
}
