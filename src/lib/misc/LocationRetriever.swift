/*

LocationRetriever manages an CLLocationManager instance. Handles prompting the user for permission transparently.

    LocationRetriever.instance.startRetrievingLocation(doStuffWhileLocating)

    if let location = LocationRetriever.instance.finishRetrievingLocation() {
        LocationRetriever.instance.reverseGeocodeLocation(location) { placemark in
            if placemark {
                print(placemark.thoroughfare)
            }
        }
    }

*/

import Foundation
import CoreLocation

class LocationRetriever: NSObject, CLLocationManagerDelegate {
    static let instance: LocationRetriever = LocationRetriever()
    
    var locationManager: CLLocationManager? = nil
    var callback: (Bool -> ())? = nil
    
    // Starts retrieving the location in the background.
    // Calls the callback after the user has potentially accepted/rejected the permission request.
    // callback argument: was the app allowed to start retrieving the location
    func startRetrievingLocation(callback: Bool -> ()) {
        
        switch CLLocationManager.authorizationStatus() {

        case .AuthorizedAlways, .AuthorizedWhenInUse:
            // User has accepted already, return with positive
            self.createLocationManager()
            callback(true)


        case .Restricted, .Denied:
            // The user has denied the request already, just let it be.
            callback(false)
            
        case .NotDetermined:
            // The user has yet to decide whether to authorize, store the callback and ask the user
            self.callback = callback
            self.tryAuthorize()
        }
    }
    
    // Stop retrieving the location and return it if possible.
    func finishRetrievingLocation() -> CLLocation? {
        guard let locationManager = self.locationManager else { return nil }
        self.locationManager = nil
        return locationManager.location
    }
    
    // A wrapper to reverse geocode a location (coordinates -> metadata)
    func reverseGeocodeLocation(location: CLLocation, callback: CLPlacemark? -> ()) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location, completionHandler: { placemarks, error in
            if let placemark = placemarks?.first {
                callback(placemark)
            } else {
                callback(nil)
            }
        })
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
    
        // The user has not yet decided, this will be called later again with a real answer
        if status == .NotDetermined { return }
        
        switch status {
        case .AuthorizedAlways, .AuthorizedWhenInUse:
            self.callback?(true)
        default:
            self.callback?(false)
        }
        
        self.callback = nil
    }
}
