//
//  DriveViewController.swift
//  Zephyr One
//
//  Created by Austin Whittier on 4/9/15.
//  Copyright (c) 2015 Zephyr Racing. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class DriveViewController: UIViewController, UIActionSheetDelegate, MKMapViewDelegate, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var recording = false
    var drive: Drive!
    
    var timer: NSTimer!
    
    var speed: Double?
    
    // MARK: - View life cycle

    override func awakeFromNib() {
        super.awakeFromNib()
        let normal = IonIcons.imageWithIcon(ion_ios_circle_outline, iconColor: UIColor.grayColor(), iconSize: 32, imageSize: CGSize(width: 32, height: 32))
        let selected = IonIcons.imageWithIcon(ion_ios_circle_filled, iconColor: self.view.tintColor, iconSize: 32, imageSize: CGSize(width: 32, height: 32))
        self.tabBarItem = UITabBarItem(title: "Drive", image: normal, selectedImage: selected)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        flatViewManager = FlatDriveViewManager()
        flatViewManager.mapView = mapView
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = CLActivityType.AutomotiveNavigation
        
        resetDrive()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        checkLocationAuthorization()
        
        locationManager.startUpdatingLocation()
        
        PFAnalytics.trackEvent("viewAppeared", dimensions: ["viewName": "DriveView"])
    }
    
    override func viewDidDisappear(animated: Bool) {
        PFAnalytics.trackEvent("viewDisappeared", dimensions: ["viewName": "DriveView"])
        
        // if we aren't recording the drive, we don't need to update location anymore
        if !recording {
            locationManager.stopUpdatingLocation()
        }
    }
    
    // MARK: - Location manager delegate, etc.
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        if recording {
            for newLocation in locations {
                if newLocation.horizontalAccuracy < 20 {
                    // FIXME: decompose this into a separate function for adding a location to a drive
                    if drive.driveData.trackPoints.count > 0 {
                        let previousLocation = drive.driveData.trackPoints.last!
                        
                        let tempDistance = newLocation.distanceFromLocation(previousLocation.location)
                        drive.driveData.distance += tempDistance
                        
                        // speed is in meters/second?
                        speed = tempDistance / newLocation.timestamp!.timeIntervalSinceDate(previousLocation.timestamp)
                    }
                    
                    let newPoint = DriveDataPoint(time: newLocation.timestamp, location: newLocation as! CLLocation, speed: speed ?? 0)
                    drive.driveData.trackPoints.append(newPoint)
                }
            }
        }
        
        if let lastLocation = locationManager.location {
            let region = MKCoordinateRegionMakeWithDistance(lastLocation.coordinate, 20, 20)
            mapView.setRegion(region, animated: true)
            
        }
    }
    
    func checkLocationAuthorization() -> Bool {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .AuthorizedAlways, .AuthorizedWhenInUse:
            return true
        case .NotDetermined:
            locationManager.requestAlwaysAuthorization()
            return true
        case .Denied:
            return false
        default:
            break
        }
        
        return false
    }
    
    // MARK: - Drive recorder
    
    func startRecording() {
        recording = true
        
        locationManager.startUpdatingLocation()
        
        timer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: Selector("timerTick"), userInfo: nil, repeats: true)
        
        drive.driveData.startTime = NSDate()
    }
    
    func timerTick() {
        let currentTime = NSDate()
        let interval = currentTime.timeIntervalSinceDate(drive.driveData.startTime)
        let timerDate = NSDate(timeIntervalSince1970: interval)
            
        var convertedSpeed: Double
        if speed != nil {
            // speed to mph
            convertedSpeed = speed! / 1609.344 * 3600
        } else {
            convertedSpeed = 0.0
        }
            
        tick(timerDate, speed: convertedSpeed)
    }
    
    func stopRecording() {
        recording = false
        
        timer.invalidate()
        
        drive.driveData.endTime = NSDate()
    }
    
    func resetDrive() {
        let user = PFUser.currentUser()
        
        drive = Drive(className: "Drive")
        
        tick(NSDate(timeIntervalSince1970: 0.0), speed: 0.0)
    }
    
    // MARK: - Map view
    
    @IBOutlet weak var mapView: MKMapView!
    var flatViewManager: FlatDriveViewManager!
    
    func tick(elapsedTime: NSDate, speed: Double) {
        var timeFormatter = NSDateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"
        timeFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        
        timeLabel.text = timeFormatter.stringFromDate(elapsedTime)
        
        
        speedLabel.text = NSString(format: "%.2f mph", speed) as String
        
        flatViewManager.trackPoints = drive.driveData.trackPoints
    }
    
    // MARK: - Interface controls
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var lastLapLabel: UILabel!
    
    @IBOutlet weak var startStopButton: UIButton!
    
    @IBAction func toggleRecording(sender: UIButton) {
        if !recording {
            startRecording()
            sender.setTitle("Stop recording", forState: UIControlState.Normal)
        } else {
            stopRecording()
            let saveController = SaveDriveTableViewController()
            saveController.drive = drive
            self.navigationController?.pushViewController(saveController, animated: true)

        }
    }
}
