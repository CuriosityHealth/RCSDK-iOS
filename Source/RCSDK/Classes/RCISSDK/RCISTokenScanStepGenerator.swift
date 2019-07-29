//
//  RCISTokenScanStepGenerator.swift
//  iChange
//
//  Created by James Kizer on 6/25/18.
//  Copyright © 2018 James Kizer. All rights reserved.
//

import UIKit
import ResearchSuiteTaskBuilder
import ResearchKit
import Gloss

open class RCISTokenScanStepGenerator: RSTBBaseStepGenerator {
    
    public init() {}
    
    open var supportedTypes: [String]! {
        return ["rcisTokenScan"]
    }
    
    open func generateStep(type: String, jsonObject: JSON, helper: RSTBTaskBuilderHelper) -> ORKStep? {
        
        guard let stepDescriptor = RSTBStepDescriptor(json:jsonObject),
            let client = helper.stateHelper?.objectInState(forKey: "rcisClient") as? RCISClient,
            let rcManager = helper.stateHelper?.objectInState(forKey: "rcManager") as? RCManager  else {
                return nil
        }
        
        
        let step = RCISTokenScanStep(
            identifier: stepDescriptor.identifier,
            rcisClient: client,
            rcManager: rcManager
        )
        
        step.title = stepDescriptor.title
        step.text = stepDescriptor.text
        step.isOptional = stepDescriptor.optional
        
        return step
    }
    
    open func processStepResult(type: String, jsonObject: JsonObject, result: ORKStepResult, helper: RSTBTaskBuilderHelper) -> JSON? {
        
        return nil
        
    }
    

}
