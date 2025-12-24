//
//  Sender.swift
//  hancar
//
//  Created by kinnwonjin on 12/15/25.
//
//  This model represents a chat sender used by MessageKit.
//  It conforms to SenderType and provides sender identification
//  and display name information for chat messages.
//

import MessageKit

struct Sender: SenderType {
    let senderId: String
    let displayName: String
}
