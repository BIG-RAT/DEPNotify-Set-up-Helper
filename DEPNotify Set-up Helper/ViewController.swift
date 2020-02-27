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

class Setting: NSObject {
    @objc dynamic var keyName: String
    @objc dynamic var keyValue: String
    
    init(keyName: String, keyValue: String) {
        self.keyName  = keyName
        self.keyValue = keyValue
    }
}

class ViewController: NSViewController, NSTextFieldDelegate {
    
    @objc dynamic var settingsArray = [Setting]()
    
    @IBOutlet weak var jamfServer_TextField: NSTextField!
    @IBOutlet weak var jamfUser_TextField: NSTextField!
    @IBOutlet weak var jamfUserPwd_TextField: NSSecureTextField!
    
    let REG_POPUP_LABEL_Array = ["REG_POPUP_LABEL_1_OPTIONS", "REG_POPUP_LABEL_2_OPTIONS", "REG_POPUP_LABEL_3_OPTIONS", "REG_POPUP_LABEL_4_OPTIONS"]
    
    
    @IBOutlet weak var settings_TableView: NSTableView!
    
    @IBOutlet weak var policies_TableView: NSTableView!
    var policiesTableArray: [String]?
    var uniquePolicyNameIdDict = [String:String]() // links 'policyName - (id)' to policy id
    
    var sortedNameArray = [String]()
    
//    var settingsDictionary = [String:String]()
//    var settingsTableDict = [String:String]()
    let userDefaults = UserDefaults.standard
    let fileManager = FileManager.default
    
    
    @IBAction func refreshPolicies_Action(_ sender: Any) {
        
        var firstPolicy     = true
        let jamfCreds       = "\(jamfUser_TextField.stringValue):\(jamfUserPwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        let jamfBase64Creds = (jamfUtf8Creds?.base64EncodedString())!
        policy.attributeDict.removeAll()
        policy.runList      = ""
        
        Json().getRecord(theServer: jamfServer_TextField.stringValue, base64Creds: jamfBase64Creds, theEndpoint: "policies") {
            (result: [String:AnyObject]) in
//                            print("json returned scripts: \(result)")
            if let _ = result["policies"], result.count > 0 {
                let policiesArray = result["policies"] as! [Dictionary<String, Any>]
                let policiesArrayCount = policiesArray.count
    //            print("found \(policiesArrayCount) policies")
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
                            policy.attributeDict["\(policyId)"] = ["name":"\(policyName)","trigger":""]
                            self.uniquePolicyNameIdDict["\(policyName) - (\(policyId))"] = "\(policyId)"
                        }
                    }
                }   // for i in - end
//                print("policy.attributeDict: \(String(describing: policy.attributeDict))")
//                print("uniquePolicyNameIdDict: \(String(describing: self.uniquePolicyNameIdDict))")
                self.policies_TableView.reloadData()
            }
        }   // Json().getRecord - end
    }
    
    @IBAction func generateScript_Action(_ sender: Any) {
                
        var firstPolicy = true
        for i in (0..<settingsArray.count) {
//            print("settingsArray: \(settingsArray[i].keyName) : \(settingsArray[i].keyValue)")
            // Convert comma seperated valus to expected format, one option per line
            if REG_POPUP_LABEL_Array.firstIndex(of: settingsArray[i].keyName) != nil {
                print("found popup label: \(settingsArray[i].keyName) : \(settingsArray[i].keyValue)")
                var tmpValue = settingsArray[i].keyValue
                tmpValue = tmpValue.replacingOccurrences(of: ", ", with: ",").replacingOccurrences(of: "\"", with: "")
                let tmpValueArray = tmpValue.split(separator: ",")
                keys.settingsDict[settingsArray[i].keyName] = "\(tmpValueArray)".replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: ",", with: "\n")
            } else {
                keys.settingsDict[settingsArray[i].keyName] = settingsArray[i].keyValue
            }
            
        }

        // create array of policies to run - start
//        if keys.settingsDict["TRIGGER"]! == "id" {
            for i in (0..<policy.attributeDict.count) {
                if policies_TableView.isRowSelected(i) {
                    let policyId = self.uniquePolicyNameIdDict["\(policiesTableArray![i])"]!
                    let originalPolicyName = policiesTableArray![i].replacingOccurrences(of: " - (\(policyId))", with: "").replacingOccurrences(of: ",", with: "-")
                    if firstPolicy {
                        print("selected first policy: \(policiesTableArray![i])")
                        firstPolicy = false
//                        policy.runList = "\"\(policiesTableArray![i])\", \"\(String(describing: self.uniquePolicyNameIdDict["\(policiesTableArray![i])"]!))\""
                        policy.runList = "\"\(originalPolicyName), \(policyId)\""
                    } else {
                        print("selected policy: \(policiesTableArray![i])")
//                        policy.runList = policy.runList + "\n\"\(policiesTableArray![i])\", \"\(String(describing: self.uniquePolicyNameIdDict["\(policiesTableArray![i])"]!))\""
                        policy.runList = policy.runList + "\n\"\(originalPolicyName), \(policyId)\""
                    }
                }
            }
//        }
        keys.settingsDict["POLICY_ARRAY"] = "\(policy.runList)"
        print("policy.runList: \(policy.runList)")
        // create array of policies to run - end
        
        
        let desktopDirectory = fileManager.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        var scriptName = "depNotify.sh"
        var exportURL = desktopDirectory.appendingPathComponent(scriptName)
        
        let saveDialog = NSSavePanel()
        saveDialog.canCreateDirectories = true
        saveDialog.nameFieldStringValue = scriptName
        saveDialog.beginSheetModal(for: self.view.window!){ result in
            if result == .OK {
                scriptName = saveDialog.nameFieldStringValue
                exportURL = saveDialog.url!
                print("fileName", scriptName)
                do {
                    try script.base.write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the.")
                }
                
            }
        }
        
        
        
    }
    
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
    
    @objc func tableViewDoubleClick(_ sender:AnyObject) {
      
        guard settings_TableView.selectedRow >= 0 else {
            return
        }
//        print("item: \(item)")
//        print("tableView double-click on row \(settings_TableView.selectedRow)")
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
        
        
        settings_TableView.target       = self
        settings_TableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        policies_TableView.delegate   = self
        policies_TableView.dataSource = self
        
        var firstKey = true
        
        // Testing Mode
        keys.settingsDict["TESTING_MODE"] = userDefaults.string(forKey: "TESTING_MODE") ?? "true"
        
        // General Appearance - start
        keys.settingsDict["FULLSCREEN"] = userDefaults.string(forKey: "FULLSCREEN") ?? "false"
        keys.settingsDict["BANNER_IMAGE_PATH"] = userDefaults.string(forKey: "BANNER_IMAGE_PATH") ?? "/Applications/Self Service.app/Contents/Resources/AppIcon.icns"
        keys.settingsDict["BANNER_TITLE"] = userDefaults.string(forKey: "BANNER_TITLE") ?? "Welcome to Organization"
        keys.settingsDict["MAIN_TEXT"] = userDefaults.string(forKey: "MAIN_TEXT") ?? "Thanks for choosing a Mac at Organization! We want you to have a few applications and settings configured before you get started with your new Mac. This process should take 10 to 20 minutes to complete. \n \n If you need additional software or help, please visit the Self Service app in your Applications folder or on your Dock."
        keys.settingsDict["INITAL_START_STATUS"] = userDefaults.string(forKey: "INITAL_START_STATUS") ?? "Initial Configuration Starting..."
        keys.settingsDict["INSTALL_COMPLETE_TEXT"] = userDefaults.string(forKey: "INSTALL_COMPLETE_TEXT") ?? "Configuration Complete!"
        keys.settingsDict["COMPLETE_METHOD_DROPDOWN_ALERT"] = userDefaults.string(forKey: "COMPLETE_METHOD_DROPDOWN_ALERT") ?? "false"
        keys.settingsDict["FV_ALERT_TEXT"] = userDefaults.string(forKey: "FV_ALERT_TEXT") ?? "Your Mac must logout to start the encryption process. You will be asked to enter your password and click OK or Continue a few times. Your Mac will be usable while encryption takes place."
        keys.settingsDict["FV_COMPLETE_MAIN_TEXT"] = userDefaults.string(forKey: "COMPLETE_METHOD_DROPDOWN_ALERT") ?? "Your Mac must logout to start the encryption process. You will be asked to enter your password and click OK or Continue a few times. Your Mac will be usable while encryption takes place."
        keys.settingsDict["FV_COMPLETE_BUTTON_TEXT"] = userDefaults.string(forKey: "FV_COMPLETE_BUTTON_TEXT") ?? "Logout"
        keys.settingsDict["COMPLETE_ALERT_TEXT"] = userDefaults.string(forKey: "COMPLETE_ALERT_TEXT") ?? "Your Mac is now finished with initial setup and configuration. Press Quit to get started!"
        keys.settingsDict["COMPLETE_MAIN_TEXT"] = userDefaults.string(forKey: "COMPLETE_MAIN_TEXT") ?? "Your Mac is now finished with initial setup and configuration."
        keys.settingsDict["COMPLETE_BUTTON_TEXT"] = userDefaults.string(forKey: "COMPLETE_BUTTON_TEXT") ?? "Get Started!"
        // General Appearance - end
        
        // Plist Configuration - start
        keys.settingsDict["DEP_NOTIFY_USER_INPUT_PLIST"] = userDefaults.string(forKey: "DEP_NOTIFY_USER_INPUT_PLIST") ?? "/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotifyUserInput.plist"
        // Plist Configuration - end
        
        keys.settingsDict["STATUS_TEXT_ALIGN"] = userDefaults.string(forKey: "STATUS_TEXT_ALIGN") ?? "center"
        keys.settingsDict["HELP_BUBBLE_TITLE"] = userDefaults.string(forKey: "HELP_BUBBLE_TITLE") ?? "Need Help?"
        keys.settingsDict["HELP_BUBBLE_BODY"] = userDefaults.string(forKey: "HELP_BUBBLE_BODY") ?? "This tool at Organization is designed to help with new employee onboarding. If you have issues, please give us a call at 123-456-7890"
        
        // Error Screen Text - start
        keys.settingsDict["ERROR_BANNER_TITLE"] = userDefaults.string(forKey: "ERROR_BANNER_TITLE") ?? "Uh oh, Something Needs Fixing!"
        keys.settingsDict["ERROR_MAIN_TEXT"] = userDefaults.string(forKey: "ERROR_MAIN_TEXT") ?? "We are sorry that you are experiencing this inconvenience with your new Mac. However, we have the nerds to get you back up and running in no time! \n \n Please contact IT right away and we will take a look at your computer ASAP. \n \n Phone: 123-456-7890"
        keys.settingsDict["ERROR_STATUS"] = userDefaults.string(forKey: "ERROR_STATUS") ?? "Setup Failed"
        // Error Screen Text - end
        
        // How the policies are called, event or id -> don't see a need for this
//        keys.settingsDict["TRIGGER"] = userDefaults.string(forKey: "TRIGGER") ?? "id"
        
        // Policy Variable to Modify - defined through policies_TableView selection(s)
        
        // Caffeinate / No Sleep Configuration
        keys.settingsDict["NO_SLEEP"] = userDefaults.string(forKey: "NO_SLEEP") ?? "false"
        
        // Self Service
        keys.settingsDict["SELF_SERVICE_CUSTOM_BRANDING"] = userDefaults.string(forKey: "SELF_SERVICE_CUSTOM_BRANDING") ?? "false"
        keys.settingsDict["SELF_SERVICE_APP_NAME"] = userDefaults.string(forKey: "SELF_SERVICE_APP_NAME") ?? "Self Service.app"
        
        // EULA Variables to Modify - start
        keys.settingsDict["EULA_ENABLED"] = userDefaults.string(forKey: "EULA_ENABLED") ?? "false"
        keys.settingsDict["EULA_STATUS"] = userDefaults.string(forKey: "EULA_STATUS") ?? "Waiting on completion of EULA acceptance"
        keys.settingsDict["EULA_BUTTON"] = userDefaults.string(forKey: "EULA_BUTTON") ?? "Read and Agree to EULA"
        keys.settingsDict["EULA_MAIN_TITLE"] = userDefaults.string(forKey: "EULA_MAIN_TITLE") ?? "Organization End User License Agreement"
        keys.settingsDict["EULA_SUBTITLE"] = userDefaults.string(forKey: "EULA_SUBTITLE") ?? "Please agree to the following terms and conditions to start configuration of this Mac"
        keys.settingsDict["EULA_FILE_PATH"] = userDefaults.string(forKey: "EULA_FILE_PATH") ?? "/Users/Shared/eula.txt"
        // EULA Variables to Modify - end
        
        // Registration Variables to Modify - start
        keys.settingsDict["REGISTRATION_ENABLED"] = userDefaults.string(forKey: "REGISTRATION_ENABLED") ?? "false"
        keys.settingsDict["REGISTRATION_TITLE"] = userDefaults.string(forKey: "REGISTRATION_TITLE") ?? "Register Mac at Organization"
        keys.settingsDict["REGISTRATION_STATUS"] = userDefaults.string(forKey: "REGISTRATION_STATUS") ?? "Waiting on completion of computer registration"
        keys.settingsDict["REGISTRATION_BUTTON"] = userDefaults.string(forKey: "REGISTRATION_BUTTON") ?? "Register Your Mac"
        keys.settingsDict["REGISTRATION_BEGIN_WORD"] = userDefaults.string(forKey: "REGISTRATION_BEGIN_WORD") ?? "Setting"
        keys.settingsDict["REGISTRATION_MIDDLE_WORD"] = userDefaults.string(forKey: "REGISTRATION_MIDDLE_WORD") ?? "to"
        // Registration Variables to Modify - end
        
        // First Text Field - start
        keys.settingsDict["REG_TEXT_LABEL_1"] = userDefaults.string(forKey: "REG_TEXT_LABEL_1") ?? "Computer Name"
        keys.settingsDict["REG_TEXT_LABEL_1_PLACEHOLDER"] = userDefaults.string(forKey: "REG_TEXT_LABEL_1_PLACEHOLDER") ?? "macBook0123"
        keys.settingsDict["REG_TEXT_LABEL_1_OPTIONAL"] = userDefaults.string(forKey: "REG_TEXT_LABEL_1_OPTIONAL") ?? "false"
        keys.settingsDict["REG_TEXT_LABEL_1_HELP_TITLE"] = userDefaults.string(forKey: "REG_TEXT_LABEL_1_HELP_TITLE") ?? "Computer Name Field"
        keys.settingsDict["REG_TEXT_LABEL_1_HELP_TEXT"] = userDefaults.string(forKey: "REG_TEXT_LABEL_1_HELP_TEXT") ?? "This field is sets the name of your new Mac to what is in the Computer Name box. This is important for inventory purposes."
        // First Text Field - end
        
        // Second Text Field - start
        keys.settingsDict["REG_TEXT_LABEL_2"] = userDefaults.string(forKey: "REG_TEXT_LABEL_2") ?? "Asset Tag"
        keys.settingsDict["REG_TEXT_LABEL_2_PLACEHOLDER"] = userDefaults.string(forKey: "REG_TEXT_LABEL_2_PLACEHOLDER") ?? "BR-549"
        keys.settingsDict["REG_TEXT_LABEL_2_OPTIONAL"] = userDefaults.string(forKey: "REG_TEXT_LABEL_2_OPTIONAL") ?? "true"
        keys.settingsDict["REG_TEXT_LABEL_2_HELP_TITLE"] = userDefaults.string(forKey: "REG_TEXT_LABEL_2_HELP_TITLE") ?? "Asset Tag Field"
        keys.settingsDict["REG_TEXT_LABEL_2_HELP_TEXT"] = userDefaults.string(forKey: "REG_TEXT_LABEL_2_HELP_TEXT") ?? "This field is used to give an updated asset tag to our asset management system. If you do not know your asset tag number, please skip this field."
        // Second Text Field - end
        
        // Popup 1 - start
        keys.settingsDict["REG_POPUP_LABEL_1"] = userDefaults.string(forKey: "REG_POPUP_LABEL_1") ?? "Building"
        keys.settingsDict["REG_POPUP_LABEL_1_OPTIONS"] = userDefaults.string(forKey: "REG_POPUP_LABEL_1_OPTIONS") ?? "Amsterdam, Eau Claire, Minneapolis"
        keys.settingsDict["REG_POPUP_LABEL_1_HELP_TITLE"] = userDefaults.string(forKey: "REG_POPUP_LABEL_1_HELP_TITLE") ?? "Building Dropdown Field"
        keys.settingsDict["REG_POPUP_LABEL_1_HELP_TEXT"] = userDefaults.string(forKey: "REG_POPUP_LABEL_1_HELP_TEXT") ?? "Please choose the appropriate building for where you normally work. This is important for inventory purposes."
        // Popup 1 - end
        
        // Popup 2 - start
        keys.settingsDict["REG_POPUP_LABEL_2"] = userDefaults.string(forKey: "REG_POPUP_LABEL_2") ?? "Department"
        keys.settingsDict["REG_POPUP_LABEL_2_OPTIONS"] = userDefaults.string(forKey: "REG_POPUP_LABEL_2_OPTIONS") ?? "Customer Onboarding, Professional Services, Sales Engineering"
        keys.settingsDict["REG_POPUP_LABEL_2_HELP_TITLE"] = userDefaults.string(forKey: "REG_POPUP_LABEL_2_HELP_TITLE") ?? "Department Dropdown Field"
        keys.settingsDict["REG_POPUP_LABEL_2_HELP_TEXT"] = userDefaults.string(forKey: "REG_POPUP_LABEL_2_HELP_TEXT") ?? "Please choose the appropriate department for where you normally work. This is important for inventory purposes."
        // Popup 2 - end
        
        // Popup 3 - start
        keys.settingsDict["REG_POPUP_LABEL_3"] = userDefaults.string(forKey: "REG_POPUP_LABEL_3") ?? "Some Label"
        keys.settingsDict["REG_POPUP_LABEL_3_OPTIONS"] = userDefaults.string(forKey: "REG_POPUP_LABEL_3_OPTIONS") ?? "Option 1, Option 2, Option 3"
        keys.settingsDict["REG_POPUP_LABEL_3_HELP_TITLE"] = userDefaults.string(forKey: "REG_POPUP_LABEL_3_HELP_TITLE") ?? "Dropdown 3 Field"
        keys.settingsDict["REG_POPUP_LABEL_3_HELP_TEXT"] = userDefaults.string(forKey: "REG_POPUP_LABEL_3_HELP_TEXT") ?? "This dropdown is currently not in use. All code is here ready for you to use. It can also be hidden by removing the contents of the REG_POPUP_LABEL_3 variable."
        // Popup 3 - end
        
        // Popup 4 - start
        keys.settingsDict["REG_POPUP_LABEL_4"] = userDefaults.string(forKey: "REG_POPUP_LABEL_4") ?? "Some Label"
        keys.settingsDict["REG_POPUP_LABEL_4_OPTIONS"] = userDefaults.string(forKey: "REG_POPUP_LABEL_4_OPTIONS") ?? "Option 1, Option 2, Option 3"
        keys.settingsDict["REG_POPUP_LABEL_4_HELP_TITLE"] = userDefaults.string(forKey: "REG_POPUP_LABEL_4_HELP_TITLE") ?? "Dropdown 4 Field"
        keys.settingsDict["REG_POPUP_LABEL_4_HELP_TEXT"] = userDefaults.string(forKey: "REG_POPUP_LABEL_4_HELP_TEXT") ?? "This dropdown is currently not in use. All code is here ready for you to use. It can also be hidden by removing the contents of the REG_POPUP_LABEL_3 variable."
        // Popup 4 - end
        
        
        for keyName in sortedNameArray {
            if let _ = keys.settingsDict[keyName] {
                let value = keys.settingsDict[keyName]
                if !firstKey {
//                    settingsTableArray?.append([keyName:value!])
                    settingsArray.append(Setting(keyName: keyName, keyValue: value!))
                } else {
//                    settingsTableArray = [[keyName:value!]]
                    settingsArray = [Setting(keyName: keyName, keyValue: value!)]
                    firstKey = false
                }
            }
        }

//        settings_TableView.reloadData()
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}



extension ViewController: NSTableViewDataSource {
    
    func numberOfRows(in theTable: NSTableView) -> Int {

        let rowCount = policiesTableArray?.count ?? 0
        return rowCount
    }

}

extension ViewController: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let SettingNameCell  = "SettingNameCellId"
        static let SettingValueCell = "SettingValueCellId"
        static let PolicyNameCell   = "PolicyNameCellId"
    }
    
    
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
    
//        if (object_TableView == settings_TableView) {
//    //        print("[func tableView] item: \(String(describing: settingsTableArray?[row] ?? nil))")
//            guard let item = settingsTableArray?[row] else {
//                return nil
//            }
//
//    //        print("\n[NSTableViewDelegate] tableView tableView.tableColumns: \(object_TableView.tableColumns)")
//            for (key, value) in item {
//                
//        //            print("key: \(key) - value: \(value)")
//                    if tableColumn == object_TableView.tableColumns[0] {
//                        text = "\(key)"
//                        cellIdentifier = CellIdentifiers.SettingNameCell
//                    } else if tableColumn == object_TableView.tableColumns[1] {
//                        text = "\(value)"
//                        cellIdentifier = CellIdentifiers.SettingNameCell
//                    }
//                
//            }
//        } else {
//            guard let item = policiesTableArray?[row] else {
//                        return nil
//                    }
//
//
//            //        print("\n[NSTableViewDelegate] tableView tableView.tableColumns: \(object_TableView.tableColumns)")
//                        
//                //            print("key: \(key) - value: \(value)")
//                            if tableColumn == object_TableView.tableColumns[0] {
//                                text = "\(item)"
//                                cellIdentifier = CellIdentifiers.PolicyNameCell
//                            }
//                        
//        }
        guard let item = policiesTableArray?[row] else {
                    return nil
                }


        //        print("\n[NSTableViewDelegate] tableView tableView.tableColumns: \(object_TableView.tableColumns)")
                    
            //            print("key: \(key) - value: \(value)")
                        if tableColumn == object_TableView.tableColumns[0] {
                            text = "\(item)"
                            cellIdentifier = CellIdentifiers.PolicyNameCell
                        }
                    
    
        if let cell = object_TableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
}
