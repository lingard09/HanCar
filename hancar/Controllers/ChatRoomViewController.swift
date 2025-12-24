//
//  ChatRoomViewController.swift
//  hancar
//
//  Created by kinnwonjin on 12/15/25.
//
//  This view controller manages a real-time chat room for a carpool.
//  It uses MessageKit for the chat UI and Firestore for real-time
//  message synchronization. An initial notice message is automatically
//  sent when the chat room is first created.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import FirebaseFirestore
import FirebaseAuth

// MARK: - ChatRoomViewController
class ChatRoomViewController: MessagesViewController {

    var carpoolId: String!
    var carpool: Carpool!
    var currentUser: Sender!

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var messages: [MessageType] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let uid = Auth.auth().currentUser?.uid,
           let name = Auth.auth().currentUser?.displayName {
            currentUser = Sender(senderId: uid, displayName: name)
        } else {
            return
        }

        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self

        messagesCollectionView.scrollsToTop = true
        maintainPositionOnInputBarHeightChanged = true
        messageInputBar.sendButton.title = "Send"
        
        messagesCollectionView.contentInset.top = 30


        checkAndSendInitialNotice()

        listenMessages()
    }

    deinit {
        listener?.remove()
    }
    
    // MARK: - Notice auto sending
    private func checkAndSendInitialNotice() {
        guard let carpool = carpool, !carpool.notice.isEmpty else { return }
        
        let messagesRef = db.collection("chatRooms")
            .document(carpool.id)
            .collection("messages")
        
        messagesRef.limit(to: 1).getDocuments { [weak self] snapshot, error in
            guard let _ = self else { return }
            
            if error == nil, let count = snapshot?.documents.count, count == 0 {
                
                let noticeData: [String: Any] = [
                    "senderId": carpool.creatorUid,
                    "senderName": "Host",
                    "text": "[Notice]\n\(carpool.notice)",
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                messagesRef.addDocument(data: noticeData)
            }
        }
    }

    // MARK: - Firestore message loading
    private func listenMessages() {
        listener?.remove()
        
        guard let carpoolId = carpool?.id else { return }

        let chatRef = db
            .collection("chatRooms")
            .document(carpoolId)
            .collection("messages")
            .order(by: "createdAt", descending: false)

        listener = chatRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let documents = snapshot?.documents else { return }

            self.messages = documents.compactMap { ChatMessage(document: $0) }

            DispatchQueue.main.async {
                self.messagesCollectionView.reloadData()
                self.messagesCollectionView.scrollToLastItem(animated: true)
            }
        }
    }
}

// MARK: - MessageKit DataSource
extension ChatRoomViewController: MessagesDataSource {
    var currentSender: any MessageKit.SenderType {
        return currentUser
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }

    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ])
    }
}

// MARK: - MessageKit Layout & Display Delegate
extension ChatRoomViewController: MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    func configureAvatarView(_ avatarView:  AvatarView, for message:  MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        
        if case .text(let text) = message.kind,
           text.hasPrefix("[Notice]") {
            let avatar = Avatar(image:  nil, initials: "📢")
            avatarView.set(avatar: avatar)
            avatarView.backgroundColor = UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
        } else {
            let displayName = message.sender.displayName
            let initials = String(displayName.prefix(1))
            let avatar = Avatar(image: nil, initials:  initials)
            avatarView.set(avatar: avatar)
            
            if message.sender.senderId == currentUser.senderId {
                avatarView.backgroundColor = UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
            } else {
                avatarView.backgroundColor = .systemGray
            }
        }
    }
}

// MARK: - InputBar Delegate (메시지 전송)
extension ChatRoomViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard let uid = Auth.auth().currentUser?.uid,
              let name = Auth.auth().currentUser?.displayName,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        
        guard let carpoolId = carpool?.id else {
            return
        }

        let chatRef = db.collection("chatRooms")
            .document(carpoolId)
            .collection("messages")
            .document()

        let data: [String: Any] = [
            "senderId": uid,
            "senderName": name,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ]

        chatRef.setData(data)
        inputBar.inputTextView.text = ""
    }
}

