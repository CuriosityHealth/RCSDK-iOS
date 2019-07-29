//
//  RCManager.swift
//  iChange
//
//  Created by James Kizer on 1/17/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit
import ResearchSuiteExtensions
import Alamofire

public protocol RCManagerDelegate: class {
    //this gets called in the case that an invalid API is detected
    //and attempts to refresh it fail due to an invalid RCIS token
    //in this case, we can't really continue and we should probably close the app
    //note that this doesnt happen if the server is unreachable, only in the cases
    //where the token is messed up
    //returning true causes credentials to be cleared, cache to be flushed, etc
    func onInvalidToken(manager: RCManager) -> Bool
}

open class RCManager: NSObject {
    
//    todo add logic that handles case where we have an invalid API token
//    if rc client reports this failure, it should exchange old token with rcis for new one
    
    public struct Credentials {
        public let apiToken: String
        public let recordID: String
        public let rcisJWT: String?
    }
    
    static let kAPIToken = "rc_api_token"
    static let kRecordID = "rc_record_id"
    static let kRCISJWT = "rcis_jwt"
    
    var credentials: Credentials?
    public var hasJoined: Bool = false
    
    var client: RCClient!
    var rcisClient: RCISClient?
    var datapointQueue: RSGlossyQueue<RCConcreteInstrumentInstance>
    
    var credentialsQueue: DispatchQueue!
    var credentialStore: RSCredentialsStore!
    var credentialStoreQueue: DispatchQueue!
    
    var uploadQueue: DispatchQueue!
    var isUploading: Bool = false
    
    let reachabilityManager: NetworkReachabilityManager
    
    var protectedDataAvaialbleObserver: NSObjectProtocol!
    
    static var TAG = "RCManager"
    public var logger: RSLogger?
    public weak var delegate: RCManagerDelegate?
    
    private let instrumentInstanceIdentifierManager: RCInstrumentInstanceIdentifierManager
    
    public init?(
        baseURL: String,
        rcisClient: RCISClient?,
        queueStorageDirectory: String,
        store: RSCredentialsStore,
        logger: RSLogger? = nil
        ) {
        
        self.uploadQueue = DispatchQueue(label: "RCClient.UploadQueue")
        
        self.client = RCClient(
            baseURL: baseURL,
            dispatchQueue: DispatchQueue(label: UUID().uuidString)
        )
        
        self.rcisClient = rcisClient
        
        self.datapointQueue = RSGlossyQueue(directoryName: queueStorageDirectory, allowedClasses: [NSDictionary.self, NSArray.self])!
        
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first else {
            return nil
        }
        
        let rcManagerDirectoryPath = documentsPath.appending("/RCManager")
        
        var isDirectory : ObjCBool = false
        
        
        if FileManager.default.fileExists(atPath: rcManagerDirectoryPath, isDirectory: &isDirectory) {
            
            //if a file, remove file and add directory
            if !isDirectory.boolValue {
                do {
                    try FileManager.default.removeItem(atPath: rcManagerDirectoryPath)
                    //make directory
                    try FileManager.default.createDirectory(atPath:rcManagerDirectoryPath, withIntermediateDirectories: true, attributes: nil)
                    var url: URL = URL(fileURLWithPath: rcManagerDirectoryPath)
                    var resourceValues: URLResourceValues = URLResourceValues()
                    resourceValues.isExcludedFromBackup = true
                    try url.setResourceValues(resourceValues)
                }
                catch let e {
                    logger?.log(tag: "RCManager", level: .error, message: "\(e)")
                    assertionFailure()
                    return nil
                }
            }
            
        }
        else {
            
            do {
                //make directory
                try FileManager.default.createDirectory(atPath: rcManagerDirectoryPath, withIntermediateDirectories: true, attributes: nil)
                var url: URL = URL(fileURLWithPath: rcManagerDirectoryPath)
                var resourceValues: URLResourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try url.setResourceValues(resourceValues)
            }
            catch let e {
                logger?.log(tag: "RCManager", level: .error, message: "\(e)")
                assertionFailure()
                return nil
            }
            
            
        }
        
        let mapFilePath = rcManagerDirectoryPath.appending("/instrumentInstanceIdentifierManagerFile")
        
        guard let instrumentInstanceIdentifierManager = RCInstrumentInstanceIdentifierManager(mapFileName: mapFilePath) else {
            return nil
        }
        
        self.instrumentInstanceIdentifierManager = instrumentInstanceIdentifierManager
        
        self.credentialsQueue = DispatchQueue(label: "CredentialsQueue")
        
        self.credentialStore = store
        self.credentialStoreQueue = DispatchQueue(label: "CredentialStoreQueue")
        
        //try to load credentials from disk
        if let apiToken = self.credentialStore.get(key: RCManager.kAPIToken) as? String,
            let recordID = self.credentialStore.get(key: RCManager.kRecordID) as? String,
            let rcisJWT = self.credentialStore.get(key: RCManager.kRCISJWT) as? String {
            self.credentials = Credentials(apiToken: apiToken, recordID: recordID, rcisJWT: rcisJWT)
            self.hasJoined = true
        }

        guard let url = URL(string: baseURL),
            let host = url.host,
            let reachabilityManager = NetworkReachabilityManager(host: host) else {
                return nil
        }
        
        self.reachabilityManager = reachabilityManager
        
        self.logger = logger
        
        super.init()
        
        //set up listeners for the following events:
        // 1) we have access to the internet
        // 2) we have access to protected data
        
        let startUploading = self.startUploading
        
        reachabilityManager.listener = { [weak self] status in
            if reachabilityManager.isReachable {
                do {
                    try startUploading()
                } catch let error {
                    self?.logger?.log(tag: RCManager.TAG, level: .error, message: "an error occurred when first trying to upload \(error)")
                }
            }
        }
        
        if self.isSignedIn {
            reachabilityManager.startListening()
        }
        
        
        self.protectedDataAvaialbleObserver = NotificationCenter.default.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: nil) { [weak self](notification) in
            do {
                try startUploading()
            } catch let error as NSError {
                self?.logger?.log(tag: RCManager.TAG, level: .error, message: "error occurred when starting upload after device unlock: \(error.localizedDescription)")
            }
            
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.protectedDataAvaialbleObserver)
    }
    
    public func postJoinedMessage(credentials: Credentials, completion: @escaping ((Error?) -> ())) {
        if self.isSignedIn {
            completion(RCManagerErrors.alreadySignedIn)
            return
        }
        
        self.uploadQueue.async {
            
            //post message that signifies joining
            let joinedInstrument = RCJoinedInstrument(
                identifier: UUID(),
                created: Date()
            )
            
            let instrumentInstance: RCConcreteInstrumentInstance = joinedInstrument.toInstrumentInstance(builder: RCConcreteInstrumentInstance.self)! as! RCConcreteInstrumentInstance
            
            self.client.postInstrumentInstance(
                apiToken: credentials.apiToken,
                recordId: credentials.recordID,
                instrumentInstanceIdentifier: 1,
                instrumentInstance: instrumentInstance,
                completion: { (response, error) in
                    
                    if error == nil {
                        self.setCredentials(apiToken: credentials.apiToken, recordID: credentials.recordID, rcisJWT: credentials.rcisJWT)
                        self.hasJoined = true
                    }
                    
                    completion(error)
            })
            
        }
    }
    
    public func addInstrumentInstance(instrumentInstance: RCInstrumentInstance, completion: @escaping ((Error?) -> ())) {
        if !self.isSignedIn {
            completion(RCManagerErrors.notSignedIn)
            return
        }
        
        let concreteInstrumentInstanceOpt: RCConcreteInstrumentInstance? = {
            if let concreteInstrumentInstance = instrumentInstance as? RCConcreteInstrumentInstance {
                if concreteInstrumentInstance.instrumentInstanceIdentifier == nil {
                    if let instrumentInstanceIdentifier = self.instrumentInstanceIdentifierManager.getNextInstanceIdentifierAndIncrement(instrumentIdentifier: concreteInstrumentInstance.instrumentIdentifier) {
                        concreteInstrumentInstance.instrumentInstanceIdentifier = instrumentInstanceIdentifier
                        return concreteInstrumentInstance
                    }
                    else {
                        return nil
                    }
                    
                }
                else {
                    return concreteInstrumentInstance
                }
            }
            else {
                let concreteInstrumentInstance = RCConcreteInstrumentInstance.copyInstrumentInstance(instrumentInstance: instrumentInstance) as! RCConcreteInstrumentInstance
                
                if let instrumentInstanceIdentifier = self.instrumentInstanceIdentifierManager.getNextInstanceIdentifierAndIncrement(instrumentIdentifier: concreteInstrumentInstance.instrumentIdentifier) {
                    concreteInstrumentInstance.instrumentInstanceIdentifier = instrumentInstanceIdentifier
                    return concreteInstrumentInstance
                }

                return nil
            }
        }()
        
        guard let concreteInstrumentInstance = concreteInstrumentInstanceOpt else {
            completion(RCManagerErrors.instrumentInstanceIdentifierError)
            return
        }
        
        //vaidation is done by the queue
        //        if !self.client.validateDatapoint(datapoint: datapoint) {
        //            completion(LS2ManagerErrors.invalidDatapoint)
        //            return
        //        }
        
        do {
            try self.datapointQueue.addGlossyElement(element: concreteInstrumentInstance)
        } catch let error {
            completion(error)
            return
        }
        
        self.upload(fromMemory: false, retryUpload: true)
        completion(nil)
    }
    
    private func upload(fromMemory: Bool, retryUpload: Bool) {
        
        self.uploadQueue.async {
            
            let queue = self.datapointQueue
            guard !queue.isEmpty,
                !self.isUploading else {
                    return
            }
            
            let wappedGetFunction: () throws -> RSGlossyQueue<RCConcreteInstrumentInstance>.RSGlossyQueueElement? = {
                
                if fromMemory {
                    return try self.datapointQueue.getFirstInMemoryGlossyElement()
                }
                else {
                    return try self.datapointQueue.getFirstGlossyElement()
                }
                
            }
            
            do {
                
//                TODO: add instrument instance identifier to concrete instrument
//                when it gets added to the queue
                if let elementPair = try wappedGetFunction(),
                    let credentials = self.getCredentials() {
                    
                    let instrumentInstance: RCConcreteInstrumentInstance = elementPair.element
                    
                    let instrumentInstanceIdentifierOpt: Int? = instrumentInstance.instrumentInstanceIdentifier ??
                        self.instrumentInstanceIdentifierManager.getNextInstanceIdentifierAndIncrement(instrumentIdentifier: instrumentInstance.instrumentIdentifier)
                    
                    //this really shouldn't fail here...
                    guard let instrumentInstanceIdentifier = instrumentInstanceIdentifierOpt else {
                        self.logger?.log(tag: RCManager.TAG, level: .info, message: "instrument instance invalid: removing")
                        
                        do {
                            try self.datapointQueue.removeGlossyElement(element: elementPair)
                            
                        } catch let error {
                            //we tried to delete,
                            self.logger?.log(tag: RCManager.TAG, level: .error, message: "An error occurred when trying to remove the element \(error)")
                        }
                        self.upload(fromMemory: fromMemory, retryUpload: true)
                        return
                    }
                    
                    self.isUploading = true
                    self.logger?.log(tag: RCManager.TAG, level: .info, message: "posting instrument instance with id: \(String(describing: instrumentInstance.identifier))")
                    
                    self.client.postInstrumentInstance(
                        apiToken: credentials.apiToken,
                        recordId: credentials.recordID,
                        instrumentInstanceIdentifier: instrumentInstanceIdentifier,
                        instrumentInstance: instrumentInstance,
                        completion: { (response, error) in
                            
                            self.isUploading = false
                            self.processUploadResponse(
                                element: elementPair,
                                fromMemory: fromMemory,
                                retryUpload: retryUpload,
                                response: response,
                                error: error
                            )
                            
                    })

                }
                    
                else {
                    self.logger?.log(tag: RCManager.TAG, level: .info, message: "we couldnt load a valid datapoint")
                }
                
                
            } catch let error {
                //assume file system encryption error when tryong to read
                self.logger?.log(tag: RCManager.TAG, level: .error, message: "secure queue threw when trying to get first element: \(error)")
                
                //try uploading datapoint from memory
                self.upload(fromMemory: true, retryUpload: true)
                
            }
            
        }
        
    }
    
    private func processUploadResponse(element: RSGlossyQueue<RCConcreteInstrumentInstance>.RSGlossyQueueElement, fromMemory: Bool, retryUpload: Bool, response: RCClient.SubmitInstrumentInstanceResponse?, error: Error?) {
        
        if let err = error {
            
            self.logger?.log(tag: RCManager.TAG, level: .error, message: "Got error while posting datapoint: \(error.debugDescription)")
            //should we retry here?
            // and if so, under what conditions
            
            //may need to refresh
            switch error {
                
            case .some(RCClientError.invalidAPIToken):
                
                if let credentials = self.getCredentials(),
                        let rcisJWT = credentials.rcisJWT,
                    let rcisClient = self.rcisClient {
                    
                    rcisClient.refreshToken(token: rcisJWT) { (tokenResponse, error) in
                        if let error = error {
                            
                            //if invalidToken or invalidStudy, potentially clear credentials and notify app
                            //otherwise, try again later
                            switch error {
                                
                            case RCISClientError.invalidToken:
                                fallthrough
                            case RCISClientError.invalidStudy:
                                
                                let shouldLogOut: Bool = {
                                    if let delegate = self.delegate {
                                        return delegate.onInvalidToken(manager: self)
                                    }
                                    else {
                                        return true
                                    }
                                }()
                                
                                if shouldLogOut {
                                    self.logger?.log(tag: RCManager.TAG, level: .warn, message: "invalid refresh token: clearing")
                                    self.signOut(completion: { (error) in })
                                }
                                
                            default:
                                return
                                
                            }
                            
                        }
                        else if let tokenResponse = tokenResponse {
                            self.setCredentials(apiToken: tokenResponse.APIToken, recordID: tokenResponse.recordID, rcisJWT: tokenResponse.rcisJWT)
                            //it's possible that the API token has been refreshed, but RCIS has not yet been updated
                            //in that case, we don;t want to continuously keep retrying
                            if retryUpload {
                                self.upload(fromMemory: fromMemory, retryUpload: false)
                            }
                            
                        }
                        else {
                            assertionFailure()
                            return
                        }
                    }
                }
                else {
                    let shouldLogOut: Bool = {
                        if let delegate = self.delegate {
                            return delegate.onInvalidToken(manager: self)
                        }
                        else {
                            return true
                        }
                    }()
                    
                    if shouldLogOut {
                        self.logger?.log(tag: RCManager.TAG, level: .warn, message: "invalid API token: clearing")
                        self.signOut(completion: { (error) in })
                    }
                }
                
            //this datapoint is invalid and won't ever be accepted
            //we can remove it from the queue
            case .some(RCClientError.invalidInstrumentInstance):

                self.logger?.log(tag: RCManager.TAG, level: .info, message: "instrument instance invalid: removing")

                do {
                    try self.datapointQueue.removeGlossyElement(element: element)

                } catch let error {
                    //we tried to delete,
                    self.logger?.log(tag: RCManager.TAG, level: .error, message: "An error occurred when trying to remove the element \(error)")
                }

                self.upload(fromMemory: fromMemory, retryUpload: true)
                return
                
            default:
                
                let nsError = err as NSError
                switch (nsError.code) {
                case NSURLErrorNetworkConnectionLost:
                    self.logger?.log(tag: RCManager.TAG, level: .warn, message: "We have an internet connecction, but cannot connect to the server. Is it down?")
                    return
                    
                default:
                    self.logger?.log(tag: RCManager.TAG, level: .error, message: "other error: \(nsError)")
                    break
                }
            }
            
        }
        else if let _ = response {
            //remove from queue
            self.logger?.log(tag: RCManager.TAG, level: .info, message: "success: removing instrument instance")
            do {
                try self.datapointQueue.removeGlossyElement(element: element)
                
            } catch let error {
                //we tried to delete,
                self.logger?.log(tag: RCManager.TAG, level: .error, message: "An error occurred when trying to remove the element \(error)")
            }
            
            self.upload(fromMemory: fromMemory, retryUpload: true)
        }
    
    }
    
    public func startUploading() throws {
        
        if !self.isSignedIn {
            throw RCManagerErrors.notSignedIn
        }

        self.upload(fromMemory: false, retryUpload: true)
    }
    
    
    public func signOut(completion: @escaping ((Error?) -> ())) {
        self.hasJoined = false
        do {
            
            self.reachabilityManager.stopListening()
            
            try self.datapointQueue.clear()
            self.clearCredentials()
            
            try self.instrumentInstanceIdentifierManager.clear()
            
            completion(nil)
            
        } catch let error {
            self.clearCredentials()
            completion(error)
        }
        
    }
    
    
    public var isSignedIn: Bool {
//        return self.getCredentials() != nil
        return self.hasJoined
    }
    
    
    //MARK: credentials management
    private func clearCredentials() {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: nil, key: RCManager.kAPIToken)
                self.credentialStore.set(value: nil, key: RCManager.kRecordID)
                self.credentialStore.set(value: nil, key: RCManager.kRCISJWT)
            }
            self.credentials = nil
            return
        }
    }
    
    public func setCredentials(apiToken: String, recordID: String, rcisJWT: String?) {
        self.credentialsQueue.sync {
            self.credentialStoreQueue.async {
                self.credentialStore.set(value: apiToken as NSString, key: RCManager.kAPIToken)
                self.credentialStore.set(value: recordID as NSString, key: RCManager.kRecordID)
                if let rcisJWT = rcisJWT {
                    self.credentialStore.set(value: rcisJWT as NSString, key: RCManager.kRCISJWT)
                }
                
            }
            self.credentials = Credentials(apiToken: apiToken, recordID: recordID, rcisJWT: rcisJWT)
        }
    }
    
    private func getCredentials() -> Credentials? {
        return self.credentialsQueue.sync {
            return self.credentials
        }
    }

}
