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
import Dispatch


@objc public class LocationForUnity: NSObject, CLLocationManagerDelegate {




    private let activityManager: CMMotionActivityManager
    private let pedometer: CMPedometer
    private var startDate: Date?
    private var stepsCount: String
    var collectedSteps: [String] = [] {
        didSet {
            stepsCount = "0"
        }
    }
    
    @objc public static let sharedInstance = LocationForUnity()
    static var BACKGROUND_TIMER = 30 // restart location manager every 30 seconds

    let locationManager: CLLocationManager
    var timer: Timer?
    var currentBgTaskId: UIBackgroundTaskIdentifier?
    var collectedLocations: [String] = []
    var isEnabled = false

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

    @objc func applicationEnterBackground() {
        locationManager.startUpdatingLocation()
        onStart()
    }

    @objc public func startPlugin() {
        locationManager.startUpdatingLocation()
        onStart()
        isEnabled = true
        print("success")

    }
    
    @objc public func stopPlugin() {
        locationManager.stopUpdatingLocation()
        onStop()
        isEnabled = false
        timer?.invalidate()
        timer = nil
        
        if let taskId = currentBgTaskId {
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }
    
    @objc public func updateLocationInterval(seconds: Int) {
        LocationForUnity.BACKGROUND_TIMER = seconds
    }

    @objc func restart() {
        timer?.invalidate()
        timer = nil
        locationManager.startUpdatingLocation()
        onStart()
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
            locationManager.stopUpdatingLocation()
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

    private func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        beginNewBackgroundTask()
        locationManager.stopUpdatingLocation()
    }
    
    func beginNewBackgroundTask(){
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
    
    @objc public func isPluginEnabled() -> Bool {
        return isEnabled
    }
    
    @objc public func getLocation() -> String {
        if collectedLocations.count > 0 {
            return self.collectedLocations.removeFirst()
        } else {
            return "false"
        }
    }
}

extension LocationForUnity {
    private func onStart() {
        startDate = Date()
        
        checkAuthorizationStatus()
        startUpdating()
    }
    
    private func onStop() {
        startDate = nil
        
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
    }
    
    private func startUpdating() {
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
            onStop()
            
        default:break
        }
    }
    
    private func on(error: Error) {
        //handle error
    }
    
    private func updateStepsCountLabelUsing(startDate: Date) {
        pedometer.queryPedometerData(from: startDate, to: Date()) { [weak self] pedometerData, error in
            if let error = error {
                self?.on(error: error)
            } else if let pedometerData = pedometerData {
                
                DispatchQueue.main.async {
                    self?.stepsCount = String(describing: pedometerData.numberOfSteps)
                }
            }
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
            guard let pedometerData = pedometerData, error == nil else { return }
            
            DispatchQueue.main.async {
                self?.stepsCount = pedometerData.numberOfSteps.stringValue
            }
        }
    }
}

