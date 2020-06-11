//
//  LocationForUnity.swift
//  SwiftLocationPlugin
//
//  Created by user on 02/04/2020.
//  Copyright © 2020 user. All rights reserved.
//

import UIKit
import CoreLocation

@objc public class LocationForUnity: NSObject, CLLocationManagerDelegate {

    @objc public static let sharedInstance = LocationForUnity()
    static var BACKGROUND_TIMER = 30 // restart location manager every 30 seconds

    let locationManager: CLLocationManager
    var timer: Timer?
    var currentBgTaskId: UIBackgroundTaskIdentifier?
    var collectedLocations: [String] = []
    var isEnabled = false

    private override init(){
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
    }

    @objc public func startPlugin() {
        locationManager.startUpdatingLocation()
        isEnabled = true
        print("success")

    }
    
    @objc public func stopPlugin() {
        locationManager.stopUpdatingLocation()
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
