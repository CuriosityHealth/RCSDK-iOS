//
//  RCClientError.swift
//  iChange
//
//  Created by James Kizer on 1/16/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit

public enum RCClientError: Error {

//    //our errors
//    
//    case serverError
//    
//    //credentials failure : signIn
//    case credentialsFailure(descrition: String)
//    //invalid access token: postSample
//    case invalidAuthToken
//    //    //invalid refresh token: refreshAccessToken
//    //    case invalidRefreshToken
//    
//    //we've already uploaded a datapoint with this id
//    //server returns a 409
//    case dataPointConflict
//    
//    //server returns a 502
//    case badGatewayError
//    
//    //invalid response for signIn / refreshAccessToken
//    //e.g., expected field missing in json
//    case malformedResponse(responseBody: Any)
//    
//    //other errors to watch out for
//    
    //unreachable
    //convert into our own
    case unreachableError(underlyingError: NSError?)

    //others
    case otherError(underlyingError: Error?)

    case invalidInstrumentInstance
    
    case invalidAPIToken
    
    case unknownError
    
}
