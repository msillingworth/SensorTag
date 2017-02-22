//
//  ViewController.swift
//  SwiftSensorTag
//
//  Created by Mark Illingworth 15/02/2017.
//  Copyright © 2015 Anas Imtiaz. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreData

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDataSource, UITableViewDelegate {
    
    // Title labels
    var titleLabel : UILabel!
    var statusLabel : UILabel!
    
    // BLE
    var centralManager : CBCentralManager!
    var sensorTagPeripheral : CBPeripheral!
    
    // Table View
    var sensorTagTableView : UITableView!
    
    // Sensor Values
    var allSensorLabels : [String] = []
    var allSensorValues : [Double] = []
    var ambientTemperature : Double!
    var objectTemperature : Double!
    var accelerometerX : Double!
    var accelerometerY : Double!
    var accelerometerZ : Double!
    var relativeHumidity : Double!
    var magnetometerX : Double!
    var magnetometerY : Double!
    var magnetometerZ : Double!
    var gyroscopeX : Double!
    var gyroscopeY : Double!
    var gyroscopeZ : Double!
    var barometer : Double!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Initialize central manager on load
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Set up title label
        titleLabel = UILabel()
        titleLabel.text = "Sensor Tag"
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 20)
        titleLabel.sizeToFit()
        titleLabel.center = CGPoint(x: self.view.frame.midX, y: self.titleLabel.bounds.midY+28)
        self.view.addSubview(titleLabel)
        
        // Set up status label
        statusLabel = UILabel()
        statusLabel.textAlignment = NSTextAlignment.center
        statusLabel.text = "Loading..."
        statusLabel.font = UIFont(name: "HelveticaNeue-Light", size: 12)
        statusLabel.sizeToFit()
        //statusLabel.center = CGPoint(x: self.view.frame.midX, y: (titleLabel.frame.maxY + statusLabel.bounds.height/2) )
        statusLabel.frame = CGRect(x: self.view.frame.origin.x, y: self.titleLabel.frame.maxY, width: self.view.frame.width, height: self.statusLabel.bounds.height)
        self.view.addSubview(statusLabel)
        
        // Set up table view
        setupSensorTagTableView()
        
        // Initialize all sensor values and labels
        allSensorLabels = SensorTag.getSensorLabels()
        for _ in (0..<allSensorLabels.count) {
            allSensorValues.append(0)
        }
        
        // Storing Core Data
        
        var ambientTempArr: [Double] = []
        var objectTempArr: [Double] = []
        //var humidityArr: [Double] = []
        //var barometerArr: [Double] = []
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        // object that lets the app interact with Core Data
        let context = appDelegate.persistentContainer.viewContext
        
        let accelerometer = NSEntityDescription.insertNewObject(forEntityName: "Accelerometer", into: context)
        let barometer = NSEntityDescription.insertNewObject(forEntityName: "Barometer", into: context)
        let gyroscope = NSEntityDescription.insertNewObject(forEntityName: "Gyroscope", into: context)
        let humidity = NSEntityDescription.insertNewObject(forEntityName: "Humidity", into: context)
        let magnetometer =  NSEntityDescription.insertNewObject(forEntityName: "Magnetometer", into: context)
        let temperature = NSEntityDescription.insertNewObject(forEntityName: "Temperature", into: context)
        
        
        temperature.setValue(allSensorValues[0], forKey: "ambientTemp")
        temperature.setValue(allSensorValues[1], forKey: "objectTemp")
        accelerometer.setValue(allSensorValues[2], forKey: "accelxVal")
        accelerometer.setValue(allSensorValues[3], forKey: "accelyVal")
        accelerometer.setValue(allSensorValues[4], forKey: "accelzVal")
        humidity.setValue(allSensorValues[5], forKey: "humidity")
        magnetometer.setValue(allSensorValues[6], forKey: "magxVal")
        magnetometer.setValue(allSensorValues[7], forKey: "magyVal")
        magnetometer.setValue(allSensorValues[8], forKey: "magzVal")
        gyroscope.setValue(allSensorValues[9], forKey: "gyroxVal")
        gyroscope.setValue(allSensorValues[10], forKey: "gyroyVal")
        gyroscope.setValue(allSensorValues[11], forKey: "gyrozVal")
        barometer.setValue(allSensorValues[12], forKey: "pressure")

        do {
            try context.save()
            print ("Saved to CoreData model")
        }
        catch {
            // Process Error here
        }
        
        
        // Go get the data from core data
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Temperature")
        
        request.returnsObjectsAsFaults = false
        // going into coredata and getting the content in coredata and putting it into the result variable
        do {
            let results = try context.fetch(request)
            
            if results.count > 0 {
                for result in results as! [NSManagedObject] {
                    if (result.value(forKey: "ambientTemp") as? Double) != nil
                    {
                        ambientTempArr.append(result.value(forKey: "ambientTemp") as! Double)
                    }
                    if (result.value(forKey: "objectTemp") as? Double) != nil
                    {
                        objectTempArr.append(result.value(forKey: "objectTemp") as! Double)
                    }
                }
                    print("The ambient temperature are \(ambientTempArr)")
                    print("The object temperature are \(objectTempArr)")

            }
        }
        
        catch {
            // Process Error here
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    /******* CBCentralManagerDelegate *******/
     
     // Check status of BLE hardware
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripherals(withServices: nil, options: nil)
            self.statusLabel.text = "Searching for BLE Devices"
        }
        else {
            // Can have different conditions for all states if needed - show generic alert for now
            showAlertWithText("Error", message: "Bluetooth switched off or not initialized")
        }
    }
    
    
    // Check out the discovered peripherals to find Sensor Tag
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if SensorTag.sensorTagFound(advertisementData) == true {
            
            // Update Status Label
            self.statusLabel.text = "Sensor Tag Found"
            
            // Stop scanning, set as the peripheral to use and establish connection
            self.centralManager.stopScan()
            self.sensorTagPeripheral = peripheral
            self.sensorTagPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
        else {
            self.statusLabel.text = "Sensor Tag NOT Found"
            //showAlertWithText(header: "Warning", message: "SensorTag has not been Not Found")
        }
    }
    
    // Discover services of the peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.statusLabel.text = "Discovering peripheral services"
        peripheral.discoverServices(nil)
    }
    
    
    // If disconnected, start searching again
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.statusLabel.text = "Disconnected"
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    /******* CBCentralPeripheralDelegate *******/
     
     // Check if the service discovered is valid i.e. one of the following:
     // IR Temperature Service
     // Accelerometer Service
     // Humidity Service
     // Magnetometer Service
     // Barometer Service
     // Gyroscope Service
     // (Others are not implemented)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.statusLabel.text = "Looking at peripheral services"
        for service in peripheral.services! {
            let thisService = service as CBService
            if SensorTag.validService(thisService) {
                // Discover characteristics of all valid services
                peripheral.discoverCharacteristics(nil, for: thisService)
            }
        }
    }
    
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        self.statusLabel.text = "Enabling sensors"
        
        var enableValue = 1
        let enablyBytes = NSData(bytes: &enableValue, length: allSensorLabels.count) as Data
        
        // let enablyBytes = Data(bytes: UnsafePointer<UInt8>(&enableValue), count: sizeof(UInt8))
        
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            if SensorTag.validDataCharacteristic(thisCharacteristic) {
                // Enable Sensor Notification
                self.sensorTagPeripheral.setNotifyValue(true, for: thisCharacteristic)
            }
            if SensorTag.validConfigCharacteristic(thisCharacteristic) {
                // Enable Sensor
                self.sensorTagPeripheral.writeValue(enablyBytes, for: thisCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
        
    }
    
    
    
    // Get data values when they are updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        self.statusLabel.text = "Connected"
        
        if characteristic.uuid == IRTemperatureDataUUID {
            self.ambientTemperature = SensorTag.getAmbientTemperature(characteristic.value!)
            self.objectTemperature = SensorTag.getObjectTemperature(characteristic.value!, ambientTemperature: self.ambientTemperature)
            self.allSensorValues[0] = self.ambientTemperature
            self.allSensorValues[1] = self.objectTemperature
        }
        else if characteristic.uuid == AccelerometerDataUUID {
            let allValues = SensorTag.getAccelerometerData(characteristic.value!)
            self.accelerometerX = allValues[0]
            self.accelerometerY = allValues[1]
            self.accelerometerZ = allValues[2]
            self.allSensorValues[2] = self.accelerometerX
            self.allSensorValues[3] = self.accelerometerY
            self.allSensorValues[4] = self.accelerometerZ
        }
        else if characteristic.uuid == HumidityDataUUID {
            self.relativeHumidity = SensorTag.getRelativeHumidity(characteristic.value!)
            self.allSensorValues[5] = self.relativeHumidity
        }
        else if characteristic.uuid == MagnetometerDataUUID {
            let allValues = SensorTag.getMagnetometerData(characteristic.value!)
            self.magnetometerX = allValues[0]
            self.magnetometerY = allValues[1]
            self.magnetometerZ = allValues[2]
            self.allSensorValues[6] = self.magnetometerX
            self.allSensorValues[7] = self.magnetometerY
            self.allSensorValues[8] = self.magnetometerZ
        }
        else if characteristic.uuid == GyroscopeDataUUID {
            let allValues = SensorTag.getGyroscopeData(characteristic.value!)
            self.gyroscopeX = allValues[0]
            self.gyroscopeY = allValues[1]
            self.gyroscopeZ = allValues[2]
            self.allSensorValues[9] = self.gyroscopeX
            self.allSensorValues[10] = self.gyroscopeY
            self.allSensorValues[11] = self.gyroscopeZ
        }
        else if characteristic.uuid == BarometerDataUUID {
            print("BarometerDataUUID is \(BarometerDataUUID)")
            //let allValues = SensorTag.getBarometerData(characteristic.value!)
            self.barometer = SensorTag.getBarometerData(characteristic.value!)
            //self.barometer = allValues[0]
            self.allSensorValues[12] = self.barometer
        }
        
        self.sensorTagTableView.reloadData()
    }
    
    
    
    
    
    /******* UITableViewDataSource *******/
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allSensorLabels.count
    }
    
    
    /******* UITableViewDelegate *******/
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let thisCell = tableView.dequeueReusableCell(withIdentifier: "sensorTagCell") as! SensorTagTableViewCell
        thisCell.sensorNameLabel.text  = allSensorLabels[indexPath.row]
        
        let valueString = NSString(format: "%.2f", allSensorValues[indexPath.row])
        thisCell.sensorValueLabel.text = valueString as String
        
        return thisCell
    }
    
    
    
    
    /******* Helper *******/
     
     // Show alert
    func showAlertWithText (_ header : String = "Warning", message : String) {
        let alert = UIAlertController(title: header, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
        alert.view.tintColor = UIColor.red
        self.present(alert, animated: true, completion: nil)
    }
    
    
    // Set up Table View
    func setupSensorTagTableView () {
        
        self.sensorTagTableView = UITableView()
        self.sensorTagTableView.delegate = self
        self.sensorTagTableView.dataSource = self
        
        
        self.sensorTagTableView.frame = CGRect(x: self.view.bounds.origin.x, y: self.statusLabel.frame.maxY+20, width: self.view.bounds.width, height: self.view.bounds.height)
        
        self.sensorTagTableView.register(SensorTagTableViewCell.self, forCellReuseIdentifier: "sensorTagCell")
        
        self.sensorTagTableView.tableFooterView = UIView() // to hide empty lines after cells
        self.view.addSubview(self.sensorTagTableView)
    }
    
   
    
    
}


