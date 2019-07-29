//
//  RCISTokenScanStep.swift
//  iChange
//
//  Created by James Kizer on 6/25/18.
//  Copyright © 2018 James Kizer. All rights reserved.
//

import UIKit
import ResearchKit
import ResearchSuiteExtensions

open class RCISTokenScanStep: RSStep {
    
    open override func stepViewControllerClass() -> AnyClass {
        return RCISTokenStepViewController.self
    }
    
    public let rcisClient: RCISClient
    public let rcManager: RCManager
    
    public init(identifier: String, rcisClient: RCISClient, rcManager: RCManager) {
        self.rcisClient = rcisClient
        self.rcManager = rcManager
        super.init(identifier: identifier)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    

}
