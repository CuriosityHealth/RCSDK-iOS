//
//  RCInstrumentInstance.swift
//  iChange
//
//  Created by James Kizer on 1/16/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit
import Gloss
import LS2SDK

//
public protocol RCInstrumentInstance: Glossy {
    
    var identifier: String { get }
    //maps to redcap_repeat_instrument
    var instrumentIdentifier: String { get }
    var instrumentVersion: String { get }
    var instrumentInstanceIdentifier: Int? { get }
    var created: Date { get }
    //maps to redcap_repeat_instance
    //maybe this doesn't belong here??
    //what should manage this state?
//    var instrumentInstanceIdentifier: Int { get }
    var fields: JSON { get }
    
}

public protocol RCInstrumentInstanceBuilder {
    static func createInstrumentInstance(
        identifier: String,
        instrumentIdentifier: String,
        instrumentVersion: String,
        instrumentInstanceIdentifier: Int?,
        created: Date,
        fields: JSON
        ) -> RCInstrumentInstance?
    
    static func copyInstrumentInstance(instrumentInstance: RCInstrumentInstance) -> RCInstrumentInstance?
}

public protocol RCInstrumentInstanceConvertible {
    func toInstrumentInstance(builder: RCInstrumentInstanceBuilder.Type) -> RCInstrumentInstance?
}

open class RCConcreteInstrumentInstance: RCInstrumentInstance, RCInstrumentInstanceBuilder, RCInstrumentInstanceConvertible, LS2DatapointDecodable {
    
    public static func createInstrumentInstance(
        identifier: String,
        instrumentIdentifier: String,
        instrumentVersion: String,
        instrumentInstanceIdentifier: Int?,
        created: Date,
        fields: JSON
        ) -> RCInstrumentInstance? {
        
        return RCConcreteInstrumentInstance(
            identifier: identifier,
            instrumentIdentifier: instrumentIdentifier,
            instrumentVersion: instrumentVersion,
            instrumentInstanceIdentifier: instrumentInstanceIdentifier,
            created: created,
            fields: fields
        )
        
    }
    
    public static func copyInstrumentInstance(instrumentInstance: RCInstrumentInstance) -> RCInstrumentInstance? {
        return self.createInstrumentInstance(
            identifier: instrumentInstance.identifier,
            instrumentIdentifier: instrumentInstance.instrumentIdentifier,
            instrumentVersion: instrumentInstance.instrumentVersion,
            instrumentInstanceIdentifier: instrumentInstance.instrumentInstanceIdentifier,
            created: instrumentInstance.created,
            fields: instrumentInstance.fields
        )
    }
    
    public let identifier: String
    public let instrumentIdentifier: String
    public let instrumentVersion: String
    public var instrumentInstanceIdentifier: Int?
    public let created: Date
    public let fields: JSON
    
    public init(
        identifier: String,
        instrumentIdentifier: String,
        instrumentVersion: String,
        instrumentInstanceIdentifier: Int?,
        created: Date,
        fields: JSON
    ) {
        self.identifier = identifier
        self.instrumentIdentifier = instrumentIdentifier
        self.instrumentVersion = instrumentVersion
        self.instrumentInstanceIdentifier = instrumentInstanceIdentifier
        self.created = created
        self.fields = fields
    }
    
    public required init?(json: JSON) {
        guard let identifier: String = "identifier" <~~ json,
            let instrumentIdentifier: String = "instrumentIdentifier" <~~ json,
            let instrumentVersion: String = "instrumentVersion" <~~ json,
            let created: Date = Gloss.Decoder.decode(dateISO8601ForKey: "created")(json),
            let fields: JSON = "fields" <~~ json else {
            return nil
        }
        
        self.identifier = identifier
        self.instrumentIdentifier = instrumentIdentifier
        self.instrumentVersion = instrumentVersion
        self.instrumentInstanceIdentifier = "instrumentInstanceIdentifier" <~~ json
        self.created = created
        self.fields = fields
    }
    
    public required init?(datapoint: LS2Datapoint) {
        
        guard let header = datapoint.header,
            let body = datapoint.body,
            let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        let schema = header.schemaID
        
        self.identifier = header.id.uuidString
        self.instrumentIdentifier = schema.name.lowercased()
        self.instrumentVersion = schema.version.versionString
        self.created = header.acquisitionProvenance.sourceCreationDateTime
        
        let jsonFieldID = "\(schema.name.lowercased())_json"
        
        self.fields = [
            jsonFieldID: jsonString
        ]
        
    }
    
    public func toInstrumentInstance(builder: RCInstrumentInstanceBuilder.Type) -> RCInstrumentInstance? {
        return builder.createInstrumentInstance(
            identifier: self.identifier,
            instrumentIdentifier: self.instrumentIdentifier,
            instrumentVersion: self.instrumentVersion,
            instrumentInstanceIdentifier: nil,
            created: self.created,
            fields: self.fields
        )
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            "identifier" ~~> self.identifier,
            "instrumentIdentifier" ~~> self.instrumentIdentifier,
            "instrumentVersion" ~~> self.instrumentVersion,
            "instrumentInstanceIdentifier" ~~> self.instrumentInstanceIdentifier,
            Gloss.Encoder.encode(dateISO8601ForKey: "created")(self.created),
            "fields" ~~> self.fields
            ])
    }
    
    
}
