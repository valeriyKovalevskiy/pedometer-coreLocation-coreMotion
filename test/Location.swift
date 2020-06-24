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
    private let pedometer: CMPedometer
    private var stepsCount: String

    //MARK: - Location properties
    let locationManager: CLLocationManager
    var isEnabled = false
    var collectedLocations: [String] = []
    
    //MARK: - Init
    private override init(){
        pedometer = CMPedometer()
        locationManager = CLLocationManager()
        stepsCount = "0"
        
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
        isEnabled = true
        
        if CMPedometer.isStepCountingAvailable() {
            let calendar = Calendar.current
            pedometer.queryPedometerData(from: calendar.startOfDay(for: Date()), to: Date()) { (data, error) in
                print(data!)
            }
        }
        
        startUpdateLocationAndSteps()

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
        startUpdateLocationAndSteps()

    }
    
    private func stopUpdateLocationAndSteps() {
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
    }
    
    private func startUpdateLocationAndSteps() {
        locationManager.startUpdatingLocation()
        startUpdatingSteps()
    }
    
    private func startUpdatingSteps() {
        pedometer.startUpdates(from: Date()) { (data, error) in
//            print(data!.numberOfSteps.stringValue) //Debug print
            DispatchQueue.main.async {
                self.stepsCount = String.init(format: "\(data!.numberOfSteps.stringValue)")
            }
        }
    }

    
}

//MARK: - Location methods
extension LocationForUnity {
    private func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        stopUpdateLocationAndSteps()
        beginNewBackgroundTask()
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
            guard let location = locations.last else { return }
            
             ()
            beginNewBackgroundTask()
            
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            let time = location.timestamp
            if isEnabled {
                self.collectedLocations.append("\(lat),\(lon),\(time), \(stepsCount)")
                self.stepsCount = "0"
                
//                if let lastCollection = collectedLocations.last {
//                    print(lastCollection) //Debug print
//                }
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
        }
    }

    
}
