//
//  ChatMessage.swift
//  hancar
//
//  Created by kinnwonjin on 12/11/25.
//
//  This model represents a single chat message used by MessageKit.
//  It converts Firestore document data into a MessageType
//  that can be directly displayed in a chat UI.
//

import MessageKit
import FirebaseFirestore

struct ChatMessage: MessageType {

    let sender: SenderType
    let messageId: String
    let sentDate: Date
    let kind: MessageKind

    init?(document: DocumentSnapshot) {
        let data = document.data()

        guard
            let data,
            let senderId = data["senderId"] as? String,
            let senderName = data["senderName"] as? String,
            let text = data["text"] as? String,
            let timestamp = data["createdAt"] as? Timestamp
        else { return nil }

        self.sender = Sender(
            senderId: senderId,
            displayName: senderName
        )
        self.messageId = document.documentID
        self.sentDate = timestamp.dateValue()
        self.kind = .text(text)
    }
}
