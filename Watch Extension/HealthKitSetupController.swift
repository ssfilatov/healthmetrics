//
//  HealthKitSetupController.swift
//  Watch Extension
//
//  Created by Sergey Filatov on 02.08.2020.
//  Copyright © 2020 Mic Pringle. All rights reserved.
//

import Foundation
import HealthKit

extension String: Error {}

class HealthKitSetupAssistant {
  
    class func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {
      //1. Check to see if HealthKit Is Available on this device
      guard HKHealthStore.isHealthDataAvailable() else {
        completion(false, "not available")
        return
      }
      print("hk available")
        
        //3. Prepare a list of types you want HealthKit to read and write
      let healthKitTypesToWrite: Set<HKSampleType> = [HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!]
            
      let healthKitTypesToRead: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!]
      print("prepared types")
      //4. Request Authorization
      HKHealthStore().requestAuthorization(
        toShare: healthKitTypesToWrite,
        read: healthKitTypesToRead) { (success, error) in
          if error != nil {
            completion(success, error)
          }
          if (HKHealthStore().authorizationStatus(
            for: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!) == .sharingAuthorized) {
              print("Permission Granted to Access HeartRate")
            completion(success, nil)
          } else {
            completion(success, HKError.errorAuthorizationDenied as? Error)
          }
          
      }
    }
}
