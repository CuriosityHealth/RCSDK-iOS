//
//  RCISClientError.swift
//  iChange
//
//  Created by James Kizer on 6/25/18.
//  Copyright © 2018 James Kizer. All rights reserved.
//

import UIKit

public enum RCISClientError: Error {
    
    case unreachableError(underlyingError: NSError?)
    case otherError(underlyingError: NSError?)
    case malformedResponse(responseBody: Any)
    
    //server returns a 502
    case badGatewayError
    
    case invalidToken
    case invalidStudy

}
