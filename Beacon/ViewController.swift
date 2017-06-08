//
//  ViewController.swift
//  Beacon
//
//  Created by SSLAB on 2017/5/30.
//  Copyright © 2017年 SSLAB. All rights reserved.
//

import UIKit
import Firebase


class ViewController: UIViewController, ESTDeviceManagerDelegate, ESTDeviceConnectableDelegate{
    
    var deviceManger: ESTDeviceManager!
    var deviceBox: Array<ESTDeviceLocationBeacon>! = []
    var device: ESTDeviceLocationBeacon!
    var ownBeaconlistID: Array<String>! = []
    var ref: DatabaseReference!
    var searchTime = 30 //second
    var beaconSettingTimer: Timer?
    var executeCont = 0;
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var modeLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.deviceManger = ESTDeviceManager()
        self.deviceManger.delegate = self
        self.ref = Database.database().reference()

        let timer: Timer?
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(ViewController.searchTimeShow)), userInfo: nil, repeats: true)
        
        delay(searchTime){
            timer?.invalidate()
            self.modeLabel.text = "Setting\nget \(self.deviceBox.count) devices"
            self.deviceManger.stopDeviceDiscovery()
            if self.deviceBox.count > 0 {
                self.beaconSettingTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: (#selector(ViewController.beaconSetting)), userInfo: nil, repeats: true)
                //self.beaconSetting(settingDevice: self.deviceBox)
            }
        }
        
        //get beacon list
        let Request = ESTRequestV2GetDevices()
        Request.sendRequest { ( list: [ESTDeviceDetails]?, error: Error?) in
            if list != nil {
                for beaconList in list! {
                    self.ownBeaconlistID.append(beaconList.identifier)
                    print(beaconList.identifier)
                }
                self.deviceManger.startDeviceDiscovery(with: ESTDeviceFilterLocationBeacon(identifiers: self.ownBeaconlistID))
                //self.modeLabel.text = "Search Beacon"
                self.statusLabel.text = "Start to scan..."
            }
        }
       
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //discover device
    func deviceManager(_ manager: ESTDeviceManager, didDiscover devices: [ESTDevice]) {
        
        guard let beacon = devices.first as? ESTDeviceLocationBeacon else { return }
        print("Get beacon ID: \(beacon.identifier)")
        self.statusLabel.text = "\(beacon.identifier)"
        
        self.deviceManger.stopDeviceDiscovery()
        self.device = beacon
        if !self.deviceBox.contains(where: { $0.identifier == self.device.identifier }){
            print("try to connect "+self.device.identifier)
            self.statusLabel.text = "Try to connect:\n"+self.device.identifier
            self.device.delegate = self
            self.device.connect()
        }
        
    }
    
    func deviceManagerDidFailDiscovery(_ manager: ESTDeviceManager) {
        print("Error!!")
        self.statusLabel.text = "Scan failed!!"
    }
    
    
    
    //connect device
    func estDeviceConnectionDidSucceed(_ device: ESTDeviceConnectable) {
        
        guard let beacon_connected = device as? ESTDeviceLocationBeacon else { return }
        
        print("Connected to \(beacon_connected.identifier)")
        self.statusLabel.text = "\(beacon_connected.identifier)\n was connected"
        
        self.deviceBox.append(beacon_connected)
        self.deviceManger.startDeviceDiscovery(with: ESTDeviceFilterLocationBeacon(identifiers: self.ownBeaconlistID))
        
//        let uuid = UUID(uuidString: "AAA07F30-F5F8-466E-AFF9-25556B57FE6D")!
//        
//        self.device.settings?.iBeacon.proximityUUID.writeValue(uuid, completion: { (uuidSetting: ESTSettingIBeaconProximityUUID?, error: Error?) in
//            print("Set UUID")
//        })
        
        //self.device.disconnect()
    }
    func estDevice(_ device: ESTDeviceConnectable, didFailConnectionWithError error: Error) {
        print("Connection failed with error: \(error)")
        
        self.deviceManger.startDeviceDiscovery(with: ESTDeviceFilterLocationBeacon(identifiers: self.ownBeaconlistID))
        //self.deviceManger.stopDeviceDiscovery()
    }
    
    func estDevice(_ device: ESTDeviceConnectable, didDisconnectWithError error: Error?) {
        print("Disconnected")
        
        self.deviceManger.startDeviceDiscovery(with: ESTDeviceFilterLocationBeacon(identifiers: self.ownBeaconlistID))
        
    }

    func beaconSetting(){
        //get Indoor && unDirty users
        self.ref.child("users").queryOrdered(byChild: "indoor").queryEqual(toValue: true).observeSingleEvent(of: .value, with: { (DataSnapshot) in
            let value = DataSnapshot.value as! NSDictionary
            var CleanUserdata = value.filter {
                let user = $0.1 as! NSDictionary
                return user["dirty"] as! Bool == false
            }
            //setting info in N devices(Beacons)
            if CleanUserdata.count > self.deviceBox.count-1 {
                for deviceSet in self.deviceBox {
                    let random = Int(arc4random_uniform(UInt32(CleanUserdata.count)))
                    print("Size: \(CleanUserdata.count), Random: \(random), ID: \(deviceSet.identifier)")
                    let user = CleanUserdata[random].value as! NSDictionary
                    let age = user["age"] as! UInt16
                    print("age: \(age)")
                    self.ref.child("users").child(CleanUserdata[random].key as! String).updateChildValues(["dirty": true])
                    CleanUserdata.remove(at: random)
                    
                    //wirte beacon
                    deviceSet.settings?.iBeacon.major.writeValue(age, completion: { (_ settingMajor: ESTSettingIBeaconMajor?, error: Error?) in
                        print("Set to Major on:\n\(deviceSet.identifier)")
                        self.statusLabel.text = "Set \(age) to Major on:\n\(deviceSet.identifier)"
                        
                    })
                    
                }
            }
            guard CleanUserdata.count < 3 else { return }
            //set all dirty to false
            print("opps!")
            value.allKeys.forEach({ key in
                self.ref.child("users").child(key as! String).updateChildValues(["dirty": false])
            })
        })
        
        executeCont = executeCont + 1
        print(executeCont)
//        for deviceSet in self.deviceBox {
//            deviceSet.settings?.iBeacon.major.writeValue(UInt16(executeCont), completion: { (_ settingMajor: ESTSettingIBeaconMajor?, error: Error?) in
//                self.statusLabel.text = "Set Major to 300\n\(deviceSet.identifier)"
//                print("Set Major to 300\n\(deviceSet.identifier)")
//                
//            })
//        }
        

    }
    
    func delay(_ delay:Int, closure:@escaping ()->()) {
        let when = DispatchTime.now() + Double(delay)
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }
    
    func searchTimeShow(){
        self.searchTime = self.searchTime - 1
        self.modeLabel.text = "SeachMode: \(self.searchTime)"
    }
    
    @IBAction func addsomthing(){
        
        self.ref.child("users").queryOrdered(byChild: "indoor").queryEqual(toValue: true).observeSingleEvent(of: .value, with: { (DataSnapshot) in
            let value = DataSnapshot.value as! NSDictionary

            var CleanUserdata = value.filter {
                    let user = $0.1 as! NSDictionary
                    return user["dirty"] as! Bool == false
            }
            var getname: String = " "
            if CleanUserdata.count > 2 {
                //setting to devices
                for _ in 1...3 {
                    //print(CleanUserdata.count)
                    let random = Int(arc4random_uniform(UInt32(CleanUserdata.count)))
                    print("Size: \(CleanUserdata.count), Random: \(random)")
                    let user = CleanUserdata[random].value as! NSDictionary
                    let name = user["age"] as! UInt16
                    getname += "\(name)" + ", "
                    self.ref.child("users").child(CleanUserdata[random].key as! String).updateChildValues(["dirty": true])
                    CleanUserdata.remove(at: random)
                }
                self.statusLabel.text = getname
            }
            guard CleanUserdata.count < 3 else { return }
            //set all dirty to false
            print("opps!")
            value.allKeys.forEach({ key in
                self.ref.child("users").child(key as! String).updateChildValues(["dirty": false])
            })

        })
        
    }
    
   }

