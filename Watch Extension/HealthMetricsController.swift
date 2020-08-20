//
//  HealthKitSetupController.swift
//  Watch Extension
//
//  Created by Sergey Filatov on 02.08.2020.
//  Copyright © 2020 Mic Pringle. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit


class HealthMetricsController: WKInterfaceController, HKWorkoutSessionDelegate {


  @IBOutlet var heart: WKInterfaceImage!
  @IBOutlet var label: WKInterfaceLabel!
  @IBOutlet var startStopButton: WKInterfaceButton!
  
  let healthStore = HKHealthStore()
  let dppUrl = "http://95.163.215.167:18124/"
  let heartRateEventType = "heartRate"
  let iso8601dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
  
  var workoutActive = false
  
  // define the activity type and location
  var session : HKWorkoutSession?
  
  var currentQuery : HKQuery?
  
  override init() {
    super.init()
    
    // mock changing heart rate
//    DispatchQueue.global(qos: .background).async {
//      for _ in 1...1000 {
//        sleep(1)
//        self.saveMockHeartData()
//      }
//    }
    
  }
  
  func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
      switch toState {
      case .running:
          workoutDidStart(date)
      case .ended:
          workoutDidEnd(date)
      default:
          print("Unexpected state \(toState)")
      }
  }
  
  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
      // Do nothing for now
      print("Workout error")
  }
  
  func workoutDidStart(_ date : Date) {
      if let query = subscribeToHeartBeatChanges() {
          self.currentQuery = query
          healthStore.execute(query)
      } else {
          label.setText("cannot start")
      }
  }
  
  func workoutDidEnd(_ date : Date) {
          healthStore.stop(self.currentQuery!)
          label.setText("---")
          session = nil
  }
  @IBAction func startBtnTapped() {
    if (self.workoutActive) {
        //finish the current workout
        self.workoutActive = false
        self.startStopButton.setTitle("Start")
        if let workout = self.session {
            healthStore.end(workout)
        }
    } else {
        //start a new workout
        self.workoutActive = true
        self.startStopButton.setTitle("Stop")
        startWorkout()
    }
  }
  
  func startWorkout() {
      
      // If we have already started the workout, then do nothing.
      if (session != nil) {
          return
      }
      
      // Configure the workout session.
      let workoutConfiguration = HKWorkoutConfiguration()
      workoutConfiguration.activityType = .crossTraining
      workoutConfiguration.locationType = .indoor
      
      do {
          session = try HKWorkoutSession(configuration: workoutConfiguration)
          session?.delegate = self
      } catch {
          fatalError("Unable to create the workout session!")
      }
      
      healthStore.start(self.session!)
  }


  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    
    HealthKitSetupAssistant.authorizeHealthKit { (authorized, error) in
          
      guard authorized else {
            
        let baseMessage = "HealthKit Authorization Failed"
            
        if let error = error {
          print("\(baseMessage). Reason: \(error.localizedDescription)")
        } else {
          print(baseMessage)
        }
            
        return
      }
          
      print("HealthKit Successfully Authorized.")
    }

  }
  
  public func saveMockHeartData() {

    // 1. Create a heart rate BPM Sample
    let heartRateQuantity = HKQuantity(unit: HKUnit(from: "count/min"),
    doubleValue: Double(arc4random_uniform(80) + 100))
    let heartRateType:HKQuantityType = HKQuantityType.quantityType(forIdentifier: .heartRate)!


    let heartSample = HKQuantitySample(type: heartRateType,
                                       quantity: heartRateQuantity, start: NSDate() as Date, end: NSDate() as Date)

    // 2. Save the sample in the store
    self.healthStore.save(heartSample, withCompletion: { (success, error) -> Void in
      if let error = error {
        print("Error saving heart sample: \(error.localizedDescription)")
      }
    })
  }
  
  public func subscribeToHeartBeatChanges() -> HKQuery? {

    // Creating the sample for the heart rate
    guard let sampleType: HKSampleType =
      HKObjectType.quantityType(forIdentifier: .heartRate) else {
        return nil
    }

    /// Creating an observer, so updates are received whenever HealthKit’s
    // heart rate data changes.
    let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { (query, completionHandler, errorOrNil) in
      if let error = errorOrNil {
          // Properly handle the error.
        print(error)
        return
      }

        /// When the completion is called, an other query is executed
        /// to fetch the latest heart rate
      self.fetchLatestHeartRateSample(completion: { sample in
        guard let sample = sample else {
          return
        }

        /// The completion in called on a background thread, but we
        /// need to update the UI on the main.
        DispatchQueue.main.async {

          /// Converting the heart rate to bpm
          let heartRateUnit = HKUnit(from: "count/min")
          let heartRate = sample
            .quantity
            .doubleValue(for: heartRateUnit)

          /// Updating the UI with the retrieved value
          self.label.setText("\(Int(heartRate))")
          self.animateHeart()
          self.sendDppMetrics(heartRate: String(Int(heartRate)), eventType: self.heartRateEventType)
        }
      })
    }
    return query
  }
  
  public func sendDppMetrics(heartRate: String, eventType: String) {
    let Url = String(format: self.dppUrl)
    guard let serviceUrl = URL(string: Url) else { return }
    let date = Date()
    let iso8601DateFormatter = ISO8601DateFormatter()
    if #available(watchOSApplicationExtension 4.0, *) {
      iso8601DateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    } else {
      // Fallback on earlier versions
      print("iso8601 time format not available")
    }
    let parameters = [
      "timestamp": iso8601DateFormatter.string(from: date),
      "event_type": eventType,
      "event": [
                "value" : heartRate,
        ]
      ] as [String : Any]
    var request = URLRequest(url: serviceUrl)
    request.httpMethod = "POST"
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted) // pass dictionary to nsdata object and set it as request body
    } catch let error {
        print(error.localizedDescription)
    }
    request.timeoutInterval = 20
    let session = URLSession.shared
    session.dataTask(with: request) { (data, response, error) in
        if let response = response {
            print(response)
        }
    }.resume()
  }
  
  public func fetchLatestHeartRateSample(
    completion: @escaping (_ sample: HKQuantitySample?) -> Void) {

    /// Create sample type for the heart rate
    guard let sampleType = HKObjectType
      .quantityType(forIdentifier: .heartRate) else {
        completion(nil)
      return
    }

    /// Predicate for specifiying start and end dates for the query
    let predicate = HKQuery
      .predicateForSamples(
        withStart: Date.distantPast,
        end: Date(),
        options: .strictEndDate)

    /// Set sorting by date.
    let sortDescriptor = NSSortDescriptor(
      key: HKSampleSortIdentifierStartDate,
      ascending: false)

    /// Create the query
    let query = HKSampleQuery(
      sampleType: sampleType,
      predicate: predicate,
      limit: Int(HKObjectQueryNoLimit),
      sortDescriptors: [sortDescriptor]) { (_, results, error) in

        guard error == nil else {
          print("Error: \(error!.localizedDescription)")
          return
        }

        completion(results?[0] as? HKQuantitySample)
    }

    self.healthStore.execute(query)
  }
  
  func animateHeart() {
      self.animate(withDuration: 0.5) {
          self.heart.setWidth(30)
          self.heart.setHeight(41)
      }
      
      let when = DispatchTime.now() + Double(Int64(0.5 * double_t(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
      
      DispatchQueue.global(qos: .default).async {
          DispatchQueue.main.asyncAfter(deadline: when) {
              self.animate(withDuration: 0.5, animations: {
                  self.heart.setWidth(40)
                  self.heart.setHeight(48)
              })            }
          
          
      }
  }
}
