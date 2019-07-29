//
//  RCManagerErrors.swift
//  iChange
//
//  Created by James Kizer on 1/17/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit

public enum RCManagerErrors: Error {
    
    case alreadySignedIn
    case notSignedIn
    case invalidDatapoint
    case hasCredentials
    case doesNotHaveCredentials
    case programmingError
    case instrumentInstanceIdentifierError

}
