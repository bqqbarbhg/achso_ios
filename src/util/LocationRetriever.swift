import Foundation
import CoreLocation

class LocationRetriever: NSObject, CLLocationManagerDelegate {
    static let instance: LocationRetriever = LocationRetriever()
    
    var locationManager: CLLocationManager? = nil
    var callback: (() -> ())? = nil
    
    func startRetrievingLocation(callback: () -> ()) {
        
        switch CLLocationManager.authorizationStatus() {
        case .AuthorizedAlways, .AuthorizedWhenInUse:
            self.createLocationManager()
            callback()
        case .NotDetermined:
            self.tryAuthorize()
            self.callback = callback
        case .Restricted, .Denied:
            // Just let the user be.
            callback()
            break
        }
    }
    
    func createLocationManager() -> CLLocationManager {
        if let locationManager = self.locationManager {
            return locationManager
        } else {
            let locationManager = CLLocationManager()
            self.locationManager = locationManager
            locationManager.delegate = self
            
            return locationManager
        }
    }
    
    func tryAuthorize() {
        let locationManager = self.createLocationManager()
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .NotDetermined { return }
        self.callback?()
        self.callback = nil
    }
    
    func finishRetrievingLocation() -> CLLocation? {
        guard let locationManager = self.locationManager else { return nil }
        self.locationManager = nil
        return locationManager.location
    }
    
    func reverseGeocodeLocation(location: CLLocation, callback: String? -> ()) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location, completionHandler: { placemarks, error in
            if let placemark = placemarks?.first {
                callback(placemark.thoroughfare)
            } else {
                callback(nil)
            }
        })
    }
}
