//
//  RCClient.swift
//  iChange
//
//  Created by James Kizer on 1/16/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit
import Alamofire
import Gloss

open class RCClient: NSObject {
    
    public struct SubmitInstrumentInstanceResponse: Decodable {

    }
    
    public static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()
    
    let baseURL: String
    let dispatchQueue: DispatchQueue?
    
    public init(baseURL: String, dispatchQueue: DispatchQueue = DispatchQueue.main) {
        self.baseURL = baseURL
        self.dispatchQueue = dispatchQueue
        
        super.init()
    }
    
    open func submitInstrumentInstanceResponseProcessor(completion: @escaping ((SubmitInstrumentInstanceResponse?, RCClientError?) -> ())) -> (DataResponse<Any>) -> () {
        
//        todo determine which error is a result of a bad API token
        
        return { jsonResponse in
            //check for actually success
            switch jsonResponse.result {
            case .success:
                guard let response = jsonResponse.response else {
                    completion(nil, RCClientError.unknownError)
                    return
                }
                
                switch (response.statusCode) {
                case 200:
                    completion(SubmitInstrumentInstanceResponse(), nil)
                    return
                    
                case 400:
                    completion(nil, RCClientError.invalidInstrumentInstance)
                    return
                    
                case 403:
                    completion(nil, RCClientError.invalidAPIToken)
                    return
                    

                default:
                    
                    if let error = jsonResponse.result.error {
                        completion(nil, RCClientError.otherError(underlyingError: error))
                        return
                    }
                    else {
                        completion(nil, RCClientError.unknownError)
                        return
                    }
                    
                }
                
                
            case .failure(let error):
                let nsError = error as NSError
                if nsError.code == NSURLErrorNotConnectedToInternet {
                    completion(nil, RCClientError.unreachableError(underlyingError: nsError))
                    return
                }
                else {
                    completion(nil, RCClientError.otherError(underlyingError: nsError))
                    return
                }
            }
            
        }
            
    }
    
    open func postInstrumentInstance(
        apiToken: String,
        recordId: String,
        instrumentInstanceIdentifier: Int,
        instrumentInstance: RCInstrumentInstance,
        completion: @escaping ((SubmitInstrumentInstanceResponse?, RCClientError?) -> ())
        ) {
        
        let baseRecord: JSON = [
            "record_id": recordId,
            "\(instrumentInstance.instrumentIdentifier)_created": RCClient.dateFormatter.string(from: instrumentInstance.created),
            "\(instrumentInstance.instrumentIdentifier)_version": instrumentInstance.instrumentVersion,
            "\(instrumentInstance.instrumentIdentifier)_complete": "2",
            "redcap_repeat_instance": instrumentInstanceIdentifier,
            "redcap_repeat_instrument": instrumentInstance.instrumentIdentifier
        ]
        
        let record: JSON = baseRecord.merging(instrumentInstance.fields) { (first, second) -> Any in
            return first
        }
        
        let jsonData = try! JSONSerialization.data(withJSONObject: [record], options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        let parameters: JSON = [
            "token": apiToken,
            "content": "record",
            "format": "json",
            "returnFormat": "json",
            "type": "flat",
            "overwriteBehavior": "normal",
            "data": jsonString
        ]
        
        let request = Alamofire.request(
            self.baseURL,
            method: .post,
            parameters: parameters
        )
        
        request.responseJSON(
            queue: self.dispatchQueue,
            completionHandler: self.submitInstrumentInstanceResponseProcessor(completion: completion)
        )

    }
}
