//
//  RCDataSink.swift
//  iChange
//
//  Created by James Kizer on 1/21/19.
//  Copyright © 2019 James Kizer. All rights reserved.
//

import UIKit
import ResearchSuiteApplicationFramework
import ResearchSuiteResultsProcessor
import LS2SDK

open class RCDataSink: RSDataSink {
    
    weak var manager: RCManager?
    
    public init(manager: RCManager) {
        self.manager = manager
    }
    
    open func add(datapoints: [RSDatapoint]) {
        datapoints.forEach({ self.add(datapoint: $0) })
    }
    
    open func add(datapoint: RSDatapoint) {
        
        guard let manager = self.manager else {
            return
        }
        
        if let convertible = datapoint as? RCInstrumentInstanceConvertible {
            
            guard let instrumentInstance = convertible.toInstrumentInstance(builder: RCConcreteInstrumentInstance.self) else {
                assertionFailure("\(datapoint) did not convert into an instrument instance")
                return
            }
            
            manager.addInstrumentInstance(instrumentInstance: instrumentInstance) { (error) in
                
            }
            
        }
        else if let convertible = datapoint as? LS2DatapointConvertible {
            
            guard let ls2Datapoint = convertible.toDatapoint(builder: LS2ConcreteDatapoint.self) else {
                assertionFailure("\(datapoint) did not convert into an instrument instance")
                return
            }
            
            guard let instrumentInstance = RCConcreteInstrumentInstance.init(datapoint: ls2Datapoint) else {
                assertionFailure("\(ls2Datapoint) did not convert into an instrument instance")
                return
            }
            
            manager.addInstrumentInstance(instrumentInstance: instrumentInstance) { (error) in
                
            }
            
        }
        else {
            assertionFailure("\(datapoint) did not convert into an instrument instance")
        }
        
    }
    

}
