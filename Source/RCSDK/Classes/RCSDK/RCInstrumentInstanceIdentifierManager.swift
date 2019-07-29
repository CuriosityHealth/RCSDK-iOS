//
//  RCInstrumentInstanceIdentifierManager.swift
//  iChange
//
//  Created by James Kizer on 1/17/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit
import SecureQueue

class RCInstrumentInstanceIdentifierManager: NSObject {
    
    static let InitialInstrumentInstanceIdentifier = 1
    static let FileProtection: NSData.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    
    private let mapFile: URL
    private var map: [String: NSNumber]!
    private let lockQueue: DispatchQueue
    
    public init?(mapFileName: String) {
        
        self.lockQueue = DispatchQueue(label: UUID().uuidString)
        
        let mapFile = URL(fileURLWithPath: mapFileName)
        
        let map: [String: NSNumber]? = {
            
            if FileManager.default.fileExists(atPath: mapFileName) {
                
                do {
                    let map = try RCInstrumentInstanceIdentifierManager.loadMap(mapFile: mapFile, decodingClasses: [NSDictionary.self])
                    return map
                    
                }
                catch _ {
                    
                    try? FileManager.default.removeItem(at: mapFile)
                    
                }
                
            }
            
            let map: [String: NSNumber] = [:]
            do {
                try RCInstrumentInstanceIdentifierManager.saveMap(map: map, mapFile: mapFile)
                return map
            }
            catch _ {
                return nil
            }
            
        }()
        
        if let map = map {
            self.map = map
        }
        else {
            return nil
        }
        
        self.mapFile = mapFile
        
        super.init()
    }
    
    public func getNextInstanceIdentifierAndIncrement(instrumentIdentifier: String) -> Int? {
        
        return self.lockQueue.sync {
            
            let currentValue: Int = self.map[instrumentIdentifier]?.intValue ?? RCInstrumentInstanceIdentifierManager.InitialInstrumentInstanceIdentifier
            
            //increment current value
            //create a new version of the map that includes the new value
            //try to save this map
            //if save is succcessful, return curent value
            //otherwise, return nil
            let newValue = NSNumber(integerLiteral: currentValue+1)
            
            var newMap: [String: NSNumber] = self.map
            newMap[instrumentIdentifier] = newValue
            
            do {
                try RCInstrumentInstanceIdentifierManager.saveMap(map: newMap, mapFile: self.mapFile)
                self.map = newMap
                return currentValue
            }
            catch _ {
                return nil
            }

        }
        
        
    }
    
    public func clear() throws {
        //need to better understand failure modes
        
        return try self.lockQueue.sync {
            try RCInstrumentInstanceIdentifierManager.saveMap(map: [:], mapFile: self.mapFile)
        }
        
    }
    
    private static func saveMap(map: [String: NSSecureCoding], mapFile: URL) throws {
        
        let data: Data = NSKeyedArchiver.archivedData(withRootObject: map)
        try data.write(to: mapFile, options: self.FileProtection)
        
    }
    
    private static func loadMap(mapFile: URL, decodingClasses: [Swift.AnyClass]) throws -> [String: NSNumber] {
  
        let data = try Data(contentsOf: mapFile)
        let secureUnarchiver = NSKeyedUnarchiver(forReadingWith: data)
        secureUnarchiver.requiresSecureCoding = true
        
        return secureUnarchiver.decodeObject(of: decodingClasses, forKey: NSKeyedArchiveRootObjectKey) as? [String: NSNumber] ?? [:]
        
    }

}

