//
//  ViewController.swift
//  DEPNotify Set-up Helper
//
//  Created by Leslie Helou on 2/24/20.
//  Copyright © 2020 Leslie Helou. All rights reserved.
//

import AppKit
import Cocoa
import Foundation

class ViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet weak var jamfServer_TextField: NSTextField!
    @IBOutlet weak var jamfUser_TextField: NSTextField!
    @IBOutlet weak var jamfUserPwd_TextField: NSSecureTextField!
    
//    @IBOutlet weak var settingValue_TextField: NSTextField!
    @IBOutlet weak var valueCell_TextViewCell: NSTextFieldCell!
    
    
    
    @IBAction func refreshPolicies_Action(_ sender: Any) {
        
        var firstPolicy     = true
        let jamfCreds       = "\(jamfUser_TextField.stringValue):\(jamfUserPwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        let jamfBase64Creds = (jamfUtf8Creds?.base64EncodedString())!
        
        Json().getRecord(theServer: jamfServer_TextField.stringValue, base64Creds: jamfBase64Creds, theEndpoint: "policies") {
            (result: [String:AnyObject]) in
//                            print("json returned scripts: \(result)")
            let policiesArray = result["policies"] as! [Dictionary<String, Any>]
            let policiesArrayCount = policiesArray.count
            print("found \(policiesArrayCount) policies")
            for i in (0..<policiesArrayCount) {
                let thePolicy = policiesArray[i] as [String : AnyObject]
//                print("thePolicy: \(thePolicy)")
                if let policyId = thePolicy["id"], let policyName = thePolicy["name"] {
                    // filter out policies created with Jamf (Casper) Remote
                    let nameCheck = policyName as! String
                    if nameCheck.range(of:"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] at", options: .regularExpression) == nil && nameCheck != "Update Inventory" {
                        if !firstPolicy {
                            self.policiesTableArray?.append("\(policyName) - (\(policyId))")
                        } else {
                            self.policiesTableArray = ["\(policyName) - (\(policyId))"]
                            firstPolicy = false
                        }
                    }
                }
            }   // for i in - end
//            print("policiesTableArray: \(String(describing: self.policiesTableArray))")
            self.policies_TableView.reloadData()
        }   // Json().getRecord - end
    }
    
    @IBAction func generateScript_Action(_ sender: Any) {
        for i in (0..<settingsTableArray!.count) {
//            print("settingsTableArray: \(settingsTableArray![i])")
            print("settingsTableArray: \(settingsTableArray?[i])")
        }
    }
    
    
    
    @IBOutlet weak var settings_TableView: NSTableView!
    var settingsTableArray: [[String:String]]?

    @IBOutlet weak var policies_TableView: NSTableView!
    var policiesTableArray: [String]?
    
    var sortedNameArray = [String]()
    
    var settingsDictionary = [String:String]()
    var settingsTableDict = [String:String]()
    let userDefaults = UserDefaults.standard
    
    
    
    //    @IBAction func onEnterInValue_TextField(_ sender: NSTextField) {
//        let selectedRowNumber = settings_TableView.selectedRow+1
//        print("onEnterInValue row number: \(selectedRowNumber)")
//    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.tag {
            case 0:
                print("case 0")
            case 1:
                print("case 1")
            case 2:
                print("case 2")
            default:
                break
            }
        }
    }
    
    
    @IBAction func selectKeyName(_ sender: Any)  {
        let rowSelected = settings_TableView.selectedRow
      if rowSelected >= 0 {
//        print("selected row \(rowSelected)")
//        settings_TableView.editColumn(0, row: rowSelected, with: nil, select: false)

      } else {
          print("selected row is empty")
      }
    }
    

    @objc func tableViewDoubleClick(_ sender:AnyObject) {
      
        guard settings_TableView.selectedRow >= 0, let item = settingsTableArray?[settings_TableView.selectedRow] else {
            return
        }
        print("item: \(item)")
        print("tableView double-click on row \(settings_TableView.selectedRow)")
        settings_TableView.editColumn(1, row: settings_TableView.selectedRow, with: nil, select: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // test settings - start
        jamfServer_TextField.stringValue = "https://lhelou.jamfcloud.com"
        jamfUser_TextField.stringValue   = "jssadmin"
        // test settings - end
        
        // configure TextField so that we can monitor when editing is done
        self.jamfServer_TextField.delegate = self
        self.jamfUser_TextField.delegate   = self

        // Do any additional setup after loading the view.
        let sortedNameArray = keys.nameArray.sorted()
        
        settings_TableView.delegate   = self
        settings_TableView.dataSource = self
        settings_TableView.target     = self
        settings_TableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        policies_TableView.delegate   = self
        policies_TableView.dataSource = self
        
        
        
        settingsTableArray?.removeAll()
        var firstKey = true
        // Testing Mode
        settingsTableDict["TESTING_MODE"] = userDefaults.string(forKey: "TESTING_MODE") ?? "true"
        
        // General Appearance - start
        settingsTableDict["FULLSCREEN"] = userDefaults.string(forKey: "FULLSCREEN") ?? "false"
        settingsTableDict["BANNER_IMAGE_PATH"] = userDefaults.string(forKey: "BANNER_IMAGE_PATH") ?? "/Applications/Self Service.app/Contents/Resources/AppIcon.icns"
        settingsTableDict["BANNER_TITLE"] = userDefaults.string(forKey: "BANNER_TITLE") ?? "Welcome to Organization"
        settingsTableDict["MAIN_TEXT"] = userDefaults.string(forKey: "MAIN_TEXT") ?? "Thanks for choosing a Mac at Organization! We want you to have a few applications and settings configured before you get started with your new Mac. This process should take 10 to 20 minutes to complete. \n \n If you need additional software or help, please visit the Self Service app in your Applications folder or on your Dock."
        settingsTableDict["INITAL_START_STATUS"] = userDefaults.string(forKey: "INITAL_START_STATUS") ?? "Initial Configuration Starting..."
        settingsTableDict["INSTALL_COMPLETE_TEXT"] = userDefaults.string(forKey: "INSTALL_COMPLETE_TEXT") ?? "Configuration Complete!"
        settingsTableDict["COMPLETE_METHOD_DROPDOWN_ALERT"] = userDefaults.string(forKey: "COMPLETE_METHOD_DROPDOWN_ALERT") ?? "false"
        settingsTableDict["FV_ALERT_TEXT"] = userDefaults.string(forKey: "FV_ALERT_TEXT") ?? "Your Mac must logout to start the encryption process. You will be asked to enter your password and click OK or Continue a few times. Your Mac will be usable while encryption takes place."
        settingsTableDict["FV_COMPLETE_MAIN_TEXT"] = userDefaults.string(forKey: "COMPLETE_METHOD_DROPDOWN_ALERT") ?? "false"
        settingsTableDict["FV_COMPLETE_MAIN_TEXT"] = userDefaults.string(forKey: "COMPLETE_METHOD_DROPDOWN_ALERT") ?? "Your Mac must logout to start the encryption process. You will be asked to enter your password and click OK or Continue a few times. Your Mac will be usable while encryption takes place."
        settingsTableDict["FV_COMPLETE_BUTTON_TEXT"] = userDefaults.string(forKey: "FV_COMPLETE_BUTTON_TEXT") ?? "Logout"
        settingsTableDict["COMPLETE_ALERT_TEXT"] = userDefaults.string(forKey: "COMPLETE_ALERT_TEXT") ?? "Your Mac is now finished with initial setup and configuration. Press Quit to get started!"
        settingsTableDict["COMPLETE_MAIN_TEXT"] = userDefaults.string(forKey: "COMPLETE_MAIN_TEXT") ?? "false"
        settingsTableDict["COMPLETE_METHOD_DROPDOWN_ALERT"] = userDefaults.string(forKey: "COMPLETE_METHOD_DROPDOWN_ALERT") ?? "Your Mac is now finished with initial setup and configuration."
        settingsTableDict["COMPLETE_BUTTON_TEXT"] = userDefaults.string(forKey: "COMPLETE_BUTTON_TEXT") ?? "Get Started!"
        // General Appearance - end
        
        // Plist Configuration - start
        settingsTableDict["DEP_NOTIFY_USER_INPUT_PLIST"] = userDefaults.string(forKey: "DEP_NOTIFY_USER_INPUT_PLIST") ?? "/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotifyUserInput.plist"
        // Plist Configuration - end
        
        settingsTableDict["STATUS_TEXT_ALIGN"] = userDefaults.string(forKey: "STATUS_TEXT_ALIGN") ?? "center"
        settingsTableDict["HELP_BUBBLE_TITLE"] = userDefaults.string(forKey: "HELP_BUBBLE_TITLE") ?? "Need Help?"
        settingsTableDict["HELP_BUBBLE_BODY"] = userDefaults.string(forKey: "HELP_BUBBLE_BODY") ?? "This tool at Organization is designed to help with new employee onboarding. If you have issues, please give us a call at 123-456-7890"
        
        // Error Screen Text - start
        settingsTableDict["ERROR_BANNER_TITLE"] = userDefaults.string(forKey: "ERROR_BANNER_TITLE") ?? "Uh oh, Something Needs Fixing!"
        settingsTableDict["ERROR_MAIN_TEXT"] = userDefaults.string(forKey: "ERROR_MAIN_TEXT") ?? "We are sorry that you are experiencing this inconvenience with your new Mac. However, we have the nerds to get you back up and running in no time! \n \n Please contact IT right away and we will take a look at your computer ASAP. \n \n Phone: 123-456-7890"
        settingsTableDict["ERROR_STATUS"] = userDefaults.string(forKey: "ERROR_STATUS") ?? "Setup Failed"
        // Error Screen Text - end
        
        // How the policies are called, event or id
        settingsTableDict["TRIGGER"] = userDefaults.string(forKey: "TRIGGER") ?? "event"
        
        // Policy Variable to Modify - defined through policies_TableView selection(s)
        
        // Caffeinate / No Sleep Configuration
        settingsTableDict["NO_SLEEP"] = userDefaults.string(forKey: "NO_SLEEP") ?? "false"
        
        
        
        
        for keyName in sortedNameArray {
            if let _ = settingsTableDict[keyName] {
                let value = settingsTableDict[keyName]
                if !firstKey {
                    settingsTableArray?.append([keyName:value!])
                } else {
                    settingsTableArray = [[keyName:value!]]
                    firstKey = false
                }
            }
        }

        settings_TableView.reloadData()
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}



extension ViewController: NSTableViewDataSource {
    
    func numberOfRows(in theTable: NSTableView) -> Int {
        var rowCount = 0
        if (theTable == settings_TableView) {
            print("[NSTableViewDataSource] numberOfRows: \(settingsTableArray?.count ?? 0)")
//            return settingsTableArray?.count ?? 0
            rowCount = settingsTableArray?.count ?? 0
        } else {
            rowCount = policiesTableArray?.count ?? 0
        }
        return rowCount
    }
//    func numberOfRows2(in policies_TableView: NSTableView) -> Int {
//        return policiesTableArray?.count ?? 0
//    }
}

extension ViewController: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let SettingNameCell  = "SettingNameCellId"
        static let SettingValueCell = "SettingValueCellId"
        static let PolicyNameCell   = "PolicyNameCellId"
    }
    
//    override func commitEditing() -> Bool {
//        print("commitEditing")
//        return true
//    }
//
//    func controlTextDidChange(_ obj: Notification) {
//        print("controlTextDidChange")
//    }
    
    func tableView(_ object_TableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return true
    }

    func tableView(_ object_TableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

//        print("tableView: \(object_TableView)")
//        print("entered [NSTableViewDelegate] tableView")
//        print("NSTableColumn: \(NSTableColumn.attributeKeys())")
//        print("row: \(row)")
        
        var text: String = ""
        var cellIdentifier: String = ""
    
        if (object_TableView == settings_TableView) {
    //        print("[func tableView] item: \(String(describing: settingsTableArray?[row] ?? nil))")
            guard let item = settingsTableArray?[row] else {
                return nil
            }

    //        print("\n[NSTableViewDelegate] tableView tableView.tableColumns: \(object_TableView.tableColumns)")
            for (key, value) in item {
                
        //            print("key: \(key) - value: \(value)")
                    if tableColumn == object_TableView.tableColumns[0] {
                        text = "\(key)"
                        cellIdentifier = CellIdentifiers.SettingNameCell
                    } else if tableColumn == object_TableView.tableColumns[1] {
                        text = "\(value)"
                        cellIdentifier = CellIdentifiers.SettingNameCell
                    }
                
            }
        } else {
            guard let item = policiesTableArray?[row] else {
                        return nil
                    }


            //        print("\n[NSTableViewDelegate] tableView tableView.tableColumns: \(object_TableView.tableColumns)")
                        
                //            print("key: \(key) - value: \(value)")
                            if tableColumn == object_TableView.tableColumns[0] {
                                text = "\(item)"
                                cellIdentifier = CellIdentifiers.PolicyNameCell
                            }
                        
        }
    
        if let cell = object_TableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
}
