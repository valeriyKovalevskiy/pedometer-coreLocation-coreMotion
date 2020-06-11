//
//  LocationForUnity.swift
//  SwiftLocationPlugin
//
//  Created by user on 02/04/2020.
//  Copyright © 2020 user. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion

@objc public class LocationForUnity: NSObject, CLLocationManagerDelegate {

    @objc public static let sharedInstance = LocationForUnity()
    static var BACKGROUND_TIMER = 30 // restart location manager every 30 seconds
    var timer: Timer?
    var currentBgTaskId: UIBackgroundTaskIdentifier?
    
    //MARK: - Motion properties
    private let activityManager: CMMotionActivityManager
    private let pedometer: CMPedometer
    private var startDate: Date?
    private var stepsCount: String
    private var collectedSteps: [String] = [] {
        didSet {
            stepsCount = "0"
        }
    }
    //MARK: - Location properties
    let locationManager: CLLocationManager
    var isEnabled = false
    var collectedLocations: [String] = []
    
    //MARK: - Init
    private override init(){
        
        activityManager = CMMotionActivityManager()
        pedometer = CMPedometer()
        startDate = nil
        stepsCount = "0"
        
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        if #available(iOS 9, *){
            locationManager.allowsBackgroundLocationUpdates = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    //MARK: - Public methods
    @objc public func startPlugin() {
        startUpdateLocationAndSteps()
        isEnabled = true
    }
    
    @objc public func stopPlugin() {
        stopUpdateLocationAndSteps()
        isEnabled = false
        
        timer?.invalidate()
        timer = nil
        
        if let taskId = currentBgTaskId {
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }
    
    @objc public func isPluginEnabled() -> Bool {
        isEnabled
    }
    
    @objc public func getLocation() -> String {
        collectedLocations.count > 0 ? collectedLocations.removeFirst() : "false"
    }
    
    @objc public func getSteps() -> String {
        collectedSteps.count > 0 ? collectedSteps.removeFirst() : "false"
    }
    
    @objc public func updateLocationInterval(seconds: Int) {
        LocationForUnity.BACKGROUND_TIMER = seconds
    }
    
    //MARK: - Private methods
    @objc private func applicationEnterBackground() {
        startUpdateLocationAndSteps()
    }
    
    @objc private func restart() {
        timer?.invalidate()
        timer = nil
        
        startUpdateLocationAndSteps()
    }
    
    private func beginNewBackgroundTask(){
        var previousTaskId = currentBgTaskId
        currentBgTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            //            FileLogger.log("task expired: ")
        })
        
        if let taskId = previousTaskId {
            UIApplication.shared.endBackgroundTask(taskId)
            previousTaskId = UIBackgroundTaskIdentifier.invalid
        }
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(LocationForUnity.BACKGROUND_TIMER), target: self, selector: #selector(self.restart),userInfo: nil, repeats: false)
    }
    
    private func stopUpdateLocationAndSteps() {
        locationManager.stopUpdatingLocation()
        stopUpdatingSteps()
    }
    
    private func startUpdateLocationAndSteps() {
        locationManager.startUpdatingLocation()
        startUpdatingSteps()
    }
    
}

//MARK: - Location methods
extension LocationForUnity {
    private func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        beginNewBackgroundTask()
        stopUpdateLocationAndSteps()
    }
    
    private func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case CLAuthorizationStatus.restricted: break
        //log("Restricted Access to location")
        case CLAuthorizationStatus.denied: break
        //log("User denied access to location")
        case CLAuthorizationStatus.notDetermined: break
        //log("Status not determined")
        default:
            //log("startUpdatintLocation")
            if #available(iOS 9, *){
                locationManager.requestLocation()
            } else {
                locationManager.startUpdatingLocation()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if timer == nil {
            guard let location = locations.last else {return}
            
            beginNewBackgroundTask()
            stopUpdateLocationAndSteps()
            
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            let time = location.timestamp
            if isEnabled {
                self.collectedLocations.append("\(lat),\(lon),\(time)")
                self.collectedSteps.append(stepsCount)
                
                print("\(collectedSteps)")
                print("\(collectedLocations)")
            }
            
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways:
                break
            default:
                UIApplication.shared.endBackgroundTask(currentBgTaskId ?? UIBackgroundTaskIdentifier(rawValue: 0))
            }
            
            if self.collectedLocations.count > 25 {
                self.collectedLocations.removeFirst()
            }
            
            if self.collectedSteps.count > 25 {
                self.collectedSteps.removeFirst()
            }
        }
    }

    
}

//MARK: - Motion methods
extension LocationForUnity {
    private func startUpdatingSteps() {
        startDate = Date()
        
        checkAuthorizationStatus()
        checkAvailability()
    }
    
    private func stopUpdatingSteps() {
        startDate = nil
        
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
    }
    
    private func checkAvailability() {
        if CMMotionActivityManager.isActivityAvailable() {
            startTrackingActivityType()
        }
        
        if CMPedometer.isStepCountingAvailable() {
            startCountingSteps()
        }
    }
    
    private func checkAuthorizationStatus() {
        switch CMMotionActivityManager.authorizationStatus() {
            
        case CMAuthorizationStatus.denied:
            stopUpdatingSteps()
        default:
            break
        }
    }
    
    private func startTrackingActivityType() {
        activityManager.startActivityUpdates(to: OperationQueue.main) { (activity: CMMotionActivity?) in
            guard let activity = activity else { return }
            
            DispatchQueue.main.async {
                if activity.walking {
                    print("Walking")
                } else if activity.stationary {
                    print("Stationary")
                } else if activity.running {
                    print("Running")
                } else if activity.automotive {
                    print("Automotive")
                }
            }
        }
    }
    
    private func startCountingSteps() {
        pedometer.startUpdates(from: Date()) { [weak self] pedometerData, error in
            guard let pedometerData = pedometerData else { return }
            
            if let error = error {
                print(error.localizedDescription)
            }
            DispatchQueue.main.async {
                self?.stepsCount = pedometerData.numberOfSteps.stringValue
            }
        }
    }
    
    
}

