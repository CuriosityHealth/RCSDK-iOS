//
//  RCJoinedInstrument.swift
//  iChange
//
//  Created by James Kizer on 2/18/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit
import Gloss

open class RCJoinedInstrument: RCInstrumentInstanceConvertible {
    
    public func toInstrumentInstance(
        builder: RCInstrumentInstanceBuilder.Type
        ) -> RCInstrumentInstance? {
        
        let fields = ["joined_value": true]
        
        return builder.createInstrumentInstance(
            identifier: self.identifier.uuidString,
            instrumentIdentifier: RCJoinedInstrument.instrumentIdentifier,
            instrumentVersion: RCJoinedInstrument.instrumentVersion,
            instrumentInstanceIdentifier: nil,
            created: self.created,
            fields: fields
        )
    }
    
    
    static let instrumentIdentifier: String = "joined"
    static let instrumentVersion: String = "1.0.0"
    let identifier: UUID
    let created: Date
    
    init(identifier: UUID, created: Date) {
        
        self.identifier = identifier
        self.created = created
        
    }
    
}
