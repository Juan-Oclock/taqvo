//
//  LocationManager.swift
//  Taqvo
//
//  Created by Assistant on 10/25/25
//

import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestLocation() {
        let status = manager.authorizationStatus
        print("🌍 Location authorization status: \(status.rawValue)")
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("🌍 Starting location updates...")
            manager.startUpdatingLocation()
            // Stop after getting first location
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.manager.stopUpdatingLocation()
            }
        } else {
            print("🌍 Location not authorized")
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("🌍 Authorization changed to: \(authorizationStatus.rawValue)")
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.manager.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.first else { return }
        print("🌍 Got location: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
        location = newLocation
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🌍 Location manager error: \(error.localizedDescription)")
    }
}
