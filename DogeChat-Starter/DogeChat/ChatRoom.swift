//
//  ChatRoom.swift
//  DogeChat
//
//  Created by Bari Abdul on 5/2/18.
//  Copyright © 2018 Luke Parham. All rights reserved.
//

import UIKit

protocol ChatRoomDelegate: class {
    func receivedMessages(message: Message)
}

class ChatRoom: NSObject {
    var inputStream: InputStream!
    var outputStream: OutputStream!
    weak var delegate: ChatRoomDelegate?
    
    var username = ""
    
    let maxReadLength = 4096
    
    func setupNetworkCommunication() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, "localhost" as CFString, 80, &readStream, &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        
        inputStream.delegate = self
        
        inputStream.schedule(in: .current, forMode: .commonModes)
        outputStream.schedule(in: .current, forMode: .commonModes)
        
        inputStream.open()
        outputStream.open()
    }
    
    func joinChat(username: String) {
        let data = "iam: \(username)".data(using: .ascii)!
        self.username = username
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
    
    func sendMessage(message: String) {
        let data = "msg:\(message)".data(using: .ascii)
        
        _ = data?.withUnsafeBytes { outputStream.write($0, maxLength: (data?.count)!) }
    }
    
    func stopChatSession() {
        inputStream.close()
        outputStream.close()
    }
}

extension ChatRoom: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("new message received")
            readAvailableBytes(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            print("new message received")
            stopChatSession()
        case Stream.Event.errorOccurred:
            print("error occured")
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
        default:
            print("some other event")
            break
        }
    }

    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0 {
                if let _ = stream.streamError {
                    break
                }
            }
            //construct message
            if let message = processedMessageString(buffer: buffer, lenght: numberOfBytesRead) {
                //notify interested parties
                delegate?.receivedMessages(message: message)
            }
        }
    }
    
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>, lenght: Int) -> Message? {
        guard let stringArray = String(bytesNoCopy: buffer, length: lenght, encoding: .ascii, freeWhenDone: true)?.components(separatedBy: ":"), let name = stringArray.first, let message = stringArray.last else {
            return nil
        }
        let messageSender: MessageSender = (name == self.username) ? .ourself: .someoneElse
        
        return Message(message: message, messageSender: messageSender, username: name)
    }
}
