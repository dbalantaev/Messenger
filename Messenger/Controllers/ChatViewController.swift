//
//  ChatViewController.swift
//  Messenger
//
//  Created by Дмитрий Балантаев on 26.03.2022.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage

class ChatViewController: MessagesViewController {
    
    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
     
    public let otherUserEmail: String
    
    public var isNewConversation = false
    
    private let conversationId: String?
    
    private var messages = [Message]()
    
    private var  selfSender: Sender? {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "",
               senderId: safeEmail,
               displayName: "me")
    }
    
    init(with email: String, id: String?) {
        conversationId = id
        otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "attach media",
                                            message: "what would you like to attache?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo",
                                            style: .default,
                                            handler: { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        
        let actionSheet = UIAlertController(title: "attach photo",
                                            message: "where would you like to attach a photo from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default,
                                            handler: { [weak self] _ in
            
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
            
            
        }))
        actionSheet.addAction(UIAlertAction(title: "photo library",
                                            style: .default,
                                            handler: { [weak self]  _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func listenForMessages(id: String, shouldScrollToButtom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            switch result {
                
            case .success(let messages):
                
                print("success in getting messages: \(messages)")
                
                guard !messages.isEmpty else {
                    
                    print("message are empty")
                    return
                }
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToButtom {
                        self?.messagesCollectionView.scrollToLastItem(animated: true)
                    }
                }
                
            case .failure(let error):
                
                print("failed to get messages: \(error)")
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
            if let conversationId = conversationId {
                listenForMessages(id: conversationId, shouldScrollToButtom: true)
            }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
        let imageData = image.pngData(),
        let messageId = createMessageId(),
        let conversationId = conversationId,
        let name = title,
        let selfSender = selfSender else {
            return
        }
        
        let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
        
        // upload image
        StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .success(let urlString):
                
                // ready to send message
                print("uploaded message photo: \(urlString)")
                
                guard let url  = URL(string: urlString),
                      let placeholder = UIImage(systemName: "plus") else {
                          return
                      }
                
                let media = Media(url: url,
                                  image: nil,
                                  placeholderImage: placeholder,
                                  size: .zero)
                
                let message = Message(sender: selfSender,
                                      messageId: messageId,
                                      sentDate: Date(),
                                      kind: .photo(media))
                DatabaseManager.shared.sendMessage(to: conversationId,
                                                   otherUserEmail: strongSelf.otherUserEmail,
                                                   name: name,
                                                   newMessage: message,
                                                   completion: { success in
                    if success {
                        
                        print("sent photo message")
                    } else {
                        
                        print("failed to send photo message")
                    }
                })
            case .failure(let error):
                
                print("message photo upload error \(error)")
            }
        })
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = selfSender,
              let messageId = createMessageId() else {
                  return
              }
        print("Sending: \(text)")
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        // send message
        if isNewConversation {
            // create conversation in database
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: title ?? "User", firstMessage: message, completion: { [weak self] success in
                if success {
                    
                    print("message sent")
                    
                    self?.isNewConversation = false
                } else {
                    
                    print("failed to send")
                }
            })
        } else {
            guard let conversationId = conversationId,
            let name = title else {
                return
            }
            // append to existing conversation data
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message, completion: { [weak self] success in
                if success {
                    self?.messageInputBar.inputTextView.text = nil
                    print("message sent")
                } else {
                    
                    print("failed to send")
                }
            })
        }
    }
    
    private func createMessageId() -> String? {
        
        // date, otherUserEmail, senderEmail, randomInt
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String  else {
            return nil
        }
        
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let dateString = ChatViewController.dateFormatter.string(from: Date())
        
        let newIdentefier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        
        print("created message id: \(newIdentefier)")
        
        return newIdentefier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self Sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count 
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
            
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            
            break
        }
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {

        let sender = message.sender

        if sender.senderId == selfSender?.senderId {
            
            // show our image
            if let currentUserImageURL = senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
            } else {
                
                // images/safeemail_profile_picture.png
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"

                // fetch url
                StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                    switch result {
                        
                    case .success(let url):
                        
                        self?.senderPhotoURL = url
                        
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        
                        print("\(error)")
                    }
                })
            }
        } else {
            
            // other user image
            if let otherUsrePHotoURL = otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUsrePHotoURL, completed: nil)
            } else {
                
                // fetch url
                let email = otherUserEmail
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"

                // fetch url
                StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                    switch result {
                        
                    case .success(let url):
                        
                        self?.otherUserPhotoURL = url
                        
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        
                        print("\(error)")
                    }
                })
            }
        }
    }
}

extension ChatViewController: MessageCellDelegate {
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
            
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoViewerViewController( with: imageUrl)
            
            navigationController?.pushViewController(vc, animated: true)
        default:
            
            break
        } 
    }
}
