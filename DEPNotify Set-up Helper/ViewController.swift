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
    @IBOutlet weak var savePassword_Button: NSButton!
    @IBAction func savePassword_Action(_ sender: Any) {
        savePasswordSetting()
    }
    @IBOutlet var preview_Button: NSButton!
    
    @IBOutlet weak var settings_ScrollView: NSScrollView!
    
    
    var jamfCreds = ""
        
    let REG_POPUP_LABEL_Array = ["REG_POPUP_LABEL_1_OPTIONS", "REG_POPUP_LABEL_2_OPTIONS", "REG_POPUP_LABEL_3_OPTIONS", "REG_POPUP_LABEL_4_OPTIONS"]
    
    
    @IBOutlet weak var settings_TableView: NSTableView!
    
    @IBOutlet weak var policies_TableView: NSTableView!
    var policiesTableArray: [String]?
    var uniquePolicyNameIdDict = [String:String]() // links 'policyName - (id)' to policy id
    
    var sortedNameArray = [String]()
    var currentSettingValue = ""
    
//    var settingsDictionary = [String:String]()
//    var settingsTableDict = [String:String]()
    let userDefaults    = UserDefaults.standard
    let fileManager     = FileManager.default
    var DEPNotifyPath   = URL(string: "/Applications/Utilities/DEPNotify.app")
    var DEPNotifyBinary = ""
    
    // determine if we're using dark mode
    var isDarkMode: Bool {
        let mode = userDefaults.string(forKey: "AppleInterfaceStyle")
        return mode == "Dark"
    }
    
    @objc func interfaceModeChanged(sender: NSNotification) {
        DispatchQueue.main.async {
            if self.isDarkMode {
                self.view.layer?.backgroundColor = CGColor(red: 0x24/255.0, green: 0x24/255.0, blue: 0x24/255.0, alpha: 1.0)
            } else {
                self.view.layer?.backgroundColor = CGColor(red: 0xE9/255.0, green: 0xE9/255.0, blue: 0xE9/255.0, alpha: 1.0)
            }
        }
    }
    
    @IBAction func resetValues_Action(_ sender: Any) {
        for theKey in keys.nameArray {
            userDefaults.removeObject(forKey: "\(theKey)")
        }
        userDefaults.synchronize()
        refreshKeysTable()
    }
    
    @IBAction func refreshPolicies_Action(_ sender: Any) {
        
        var firstPolicy     = true
        let jamfCreds       = "\(jamfUser_TextField.stringValue):\(jamfUserPwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        let jamfBase64Creds = (jamfUtf8Creds?.base64EncodedString())!
        policy.attributeDict.removeAll()
        policy.runList      = ""
        
        if !(jamfServer_TextField.stringValue == "" || jamfUser_TextField.stringValue == "" || jamfUserPwd_TextField.stringValue == "" ) {
            Json().getRecord(theServer: jamfServer_TextField.stringValue, base64Creds: jamfBase64Creds, theEndpoint: "policies") {
                (result: [String:AnyObject]) in
//                print("json returned scripts: \(result)")
                if let _ = result["policies"], result.count > 0 {
                    // save credentials, if marked - start
                    if self.savePassword_Button.state.rawValue == 1 {
                        let regexKey = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
                        let credKey = regexKey.stringByReplacingMatches(in: self.jamfServer_TextField.stringValue, options: [], range: NSRange(0..<self.jamfServer_TextField.stringValue.utf16.count), withTemplate: "")
                        Credentials2().save(service: "DEPNotifyHelper - "+credKey, account: self.jamfUser_TextField.stringValue, data: self.jamfUserPwd_TextField.stringValue)
                    }
                    // save credentials, if marked - end
                    
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
        } else {
            Alert().display(header: "Attention:", message: "Must supply a Jamf Server, Jamf User and associated password to refresh.")
        }
    }
    
    @IBAction func generateScript_Action(_ sender: Any) {
                
        var firstPolicy = true
        for i in (0..<settingsArray.count) {
            let rawKeyName = friendlyToRawName(friendlyName: settingsArray[i].keyName)
//            print("settingsArray: \(rawKeyName) : \(settingsArray[i].keyValue)")
            // Convert comma seperated valus to expected format, one option per line
            if REG_POPUP_LABEL_Array.firstIndex(of: rawKeyName) != nil {
//                print("found popup label: \(rawKeyName) : \(settingsArray[i].keyValue)")
                var tmpValue = settingsArray[i].keyValue
                tmpValue = tmpValue.replacingOccurrences(of: ", ", with: ",").replacingOccurrences(of: "\"", with: "")
                let tmpValueArray = tmpValue.split(separator: ",")
                keys.settingsDict[rawKeyName] = "\(tmpValueArray)".replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: ",", with: "\n")
            } else {
                keys.settingsDict[rawKeyName] = settingsArray[i].keyValue
            }
        }

        // create array of policies to run - start
            for i in (0..<policy.attributeDict.count) {
                if policies_TableView.isRowSelected(i) {
                    let policyId = self.uniquePolicyNameIdDict["\(policiesTableArray![i])"]!
                    let originalPolicyName = policiesTableArray![i].replacingOccurrences(of: " - (\(policyId))", with: "").replacingOccurrences(of: ",", with: "-")
                    if firstPolicy {
//                        print("selected first policy: \(policiesTableArray![i])")
                        firstPolicy = false
                        policy.runList = "\"\(originalPolicyName),\(policyId)\""
                    } else {
//                        print("selected policy: \(policiesTableArray![i])")
                        policy.runList = policy.runList + "\n\"\(originalPolicyName),\(policyId)\""
                    }
                }
            }
        keys.settingsDict["POLICY_ARRAY"] = "\(policy.runList)"
//        print("policy.runList: \(policy.runList)")
        // create array of policies to run - end
        
        
        let desktopDirectory = fileManager.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        var scriptName = "depNotify.sh"
        var exportURL = desktopDirectory.appendingPathComponent(scriptName)
        
        var currentScript =  """
        #!/bin/bash
        # Version 2.0.6

        #########################################################################################
        # License information
        #########################################################################################
        # Copyright 2018 Jamf Professional Services

        # Permission is hereby granted, free of charge, to any person obtaining a copy of this
        # software and associated documentation files (the "Software"), to deal in the Software
        # without restriction, including without limitation the rights to use, copy, modify, merge,
        # publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
        # to whom the Software is furnished to do so, subject to the following conditions:

        # The above copyright notice and this permission notice shall be included in all copies or
        # substantial portions of the Software.

        # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
        # INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
        # PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
        # FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
        # OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
        # DEALINGS IN THE SOFTWARE.

        #########################################################################################
        # General Information
        #########################################################################################
        # This script is designed to make implementation of DEPNotify very easy with limited
        # scripting knowledge. The section below has variables that may be modified to customize
        # the end user experience. DO NOT modify things in or below the CORE LOGIC area unless
        # major testing and validation is performed.

        # More information at: https://github.com/jamfprofessionalservices/DEP-Notify

        #########################################################################################
        # Testing Mode
        #########################################################################################
        # Testing flag will enable the following things to change:
        # Auto removal of BOM files to reduce errors
        # Sleep commands instead of policies or other changes being called
        # Quit Key set to command + control + x
          TESTING_MODE=\(keys.settingsDict["TESTING_MODE"]!) # Set variable to true or false

        #########################################################################################
        # General Appearance
        #########################################################################################
        # Flag the app to open fullscreen or as a window
          FULLSCREEN=\(keys.settingsDict["FULLSCREEN"]!) # Set variable to true or false

        # Banner image can be 600px wide by 100px high. Images will be scaled to fit
        # If this variable is left blank, the generic image will appear. If using custom Self
        # Service branding, please see the Customized Self Service Branding area below
          BANNER_IMAGE_PATH="\(keys.settingsDict["BANNER_IMAGE_PATH"]!)"

        # Update the variable below replacing "Organization" with the actual name of your organization. Example "ACME Corp Inc."
          ORG_NAME="\(keys.settingsDict["ORG_NAME"]!)"

        # Main heading that will be displayed under the image
        # If this variable is left blank, the generic banner will appear
          BANNER_TITLE="\(keys.settingsDict["BANNER_TITLE"]!)"

        # Update the variable below replacing "email helpdesk@company.com" with the actual plaintext instructions for your organization. Example "call 555-1212" or "email helpdesk@company.com"
        SUPPORT_CONTACT_DETAILS="\(keys.settingsDict["SUPPORT_CONTACT_DETAILS"]!)"

        # Paragraph text that will display under the main heading. For a new line, use \\n
        # If this variable is left blank, the generic message will appear. Leave single
        # quotes below as double quotes will break the new lines.
          MAIN_TEXT='\(keys.settingsDict["MAIN_TEXT"]!)'

        # Initial Start Status text that shows as things are firing up
          INITAL_START_STATUS="\(keys.settingsDict["INITAL_START_STATUS"]!)"

        # Text that will display in the progress bar
          INSTALL_COMPLETE_TEXT="\(keys.settingsDict["INSTALL_COMPLETE_TEXT"]!)"

        # Complete messaging to the end user can ether be a button at the bottom of the
        # app with a modification to the main window text or a dropdown alert box. Default
        # value set to false and will use buttons instead of dropdown messages.
          COMPLETE_METHOD_DROPDOWN_ALERT=\(keys.settingsDict["COMPLETE_METHOD_DROPDOWN_ALERT"]!) # Set variable to true or false

        # Script designed to automatically logout user to start FileVault process if
        # deferred enablement is detected. Text displayed if deferred status is on.
          # Option for dropdown alert box
            FV_ALERT_TEXT="\(keys.settingsDict["FV_ALERT_TEXT"]!)"
          # Options if not using dropdown alert box
            FV_COMPLETE_MAIN_TEXT='\(keys.settingsDict["FV_COMPLETE_MAIN_TEXT"]!)'
            FV_COMPLETE_BUTTON_TEXT="\(keys.settingsDict["FV_COMPLETE_BUTTON_TEXT"]!)"

        # Text that will display inside the alert once policies have finished
          # Option for dropdown alert box
            COMPLETE_ALERT_TEXT="\(keys.settingsDict["COMPLETE_ALERT_TEXT"]!)"
          # Options if not using dropdown alert box
            COMPLETE_MAIN_TEXT='\(keys.settingsDict["COMPLETE_MAIN_TEXT"]!)'
            COMPLETE_BUTTON_TEXT="\(keys.settingsDict["COMPLETE_BUTTON_TEXT"]!)"

        #########################################################################################
        # Plist Configuration
        #########################################################################################
        # The menu.depnotify.plist contains more and more things that configure the DEPNotify app
        # You may want to save the file for purposes like verifying EULA acceptance or validating
        # other options.

        # Plist Save Location
          # This wrapper allows variables that are created later to be used but also allow for
          # configuration of where the plist is stored
            INFO_PLIST_WRAPPER (){
              DEP_NOTIFY_USER_INPUT_PLIST="\(keys.settingsDict["DEP_NOTIFY_USER_INPUT_PLIST"]!)"
            }

        # Status Text Alignment
          # The status text under the progress bar can be configured to be left, right, or center
            STATUS_TEXT_ALIGN="\(keys.settingsDict["STATUS_TEXT_ALIGN"]!)"

        # Help Button Configuration
          # The help button was changed to a popup. Button will appear if title is populated.
            HELP_BUBBLE_TITLE="\(keys.settingsDict["HELP_BUBBLE_TITLE"]!)"
            HELP_BUBBLE_BODY="\(keys.settingsDict["HELP_BUBBLE_BODY"]!)"

        #########################################################################################
        # Error Screen Text
        #########################################################################################
        # If testing mode is false and configuration files are present, this text will appear to
        # the end user and asking them to contact IT. Limited window options here as the
        # assumption is that they need to call IT. No continue or exit buttons will show for
        # DEP Notify window and it will not show in fullscreen. IT staff will need to use Terminal
        # or Activity Monitor to kill DEP Notify.

        # Main heading that will be displayed under the image
          ERROR_BANNER_TITLE="\(keys.settingsDict["ERROR_BANNER_TITLE"]!)"

        # Paragraph text that will display under the main heading. For a new line, use \\n
        # If this variable is left blank, the generic message will appear. Leave single
        # quotes below as double quotes will break the new lines.
          ERROR_MAIN_TEXT='\(keys.settingsDict["ERROR_MAIN_TEXT"]!)'

        # Error status message that is displayed under the progress bar
          ERROR_STATUS="\(keys.settingsDict["ERROR_STATUS"]!)"
          
        #########################################################################################
        # Trigger to be used to call the policy -> not needed, uses policy id
        #########################################################################################
        # Policies can be called be either a custom trigger or by policy id.
        # Select either event, to call the policy by the custom trigger,
        # or id to call the policy by id.


        #########################################################################################
        # Policy Variable to Modify
        #########################################################################################
        # The policy array must be formatted "Progress Bar text,id". These will be
        # run in order as they appear below.
          POLICY_ARRAY=(
            \(String(describing: keys.settingsDict["POLICY_ARRAY"]!))
          )

        #########################################################################################
        # Caffeinate / No Sleep Configuration
        #########################################################################################
        # Flag script to keep the computer from sleeping. BE VERY CAREFUL WITH THIS FLAG!
        # This flag could expose your data to risk by leaving an unlocked computer wide open.
        # Only recommended if you are using fullscreen mode and have a logout taking place at
        # the end of configuration (like for FileVault). Some folks may use this in workflows
        # where IT staff are the primary people setting up the device. The device will be
        # allowed to sleep again once the DEPNotify app is quit as caffeinate is looking
        # at DEPNotify's process ID.
          NO_SLEEP=\(keys.settingsDict["NO_SLEEP"]!)

        #########################################################################################
        # Customized Self Service Branding
        #########################################################################################
        # Flag for using the custom branding icon from Self Service and Jamf Pro
        # This will override the banner image specified above. If you have changed the
        # name of Self Service, make sure to modify the Self Service name below.
        # Please note, custom branding is downloaded from Jamf Pro after Self Service has opened
        # at least one time. The script is designed to wait until the files have been downloaded.
        # This could take a few minutes depending on server and network resources.
          SELF_SERVICE_CUSTOM_BRANDING=\(keys.settingsDict["SELF_SERVICE_CUSTOM_BRANDING"]!) # Set variable to true or false

        # If using a name other than Self Service with Custom branding. Change the
        # name with the SELF_SERVICE_APP_NAME variable below. Keep .app on the end
          SELF_SERVICE_APP_NAME="\(keys.settingsDict["SELF_SERVICE_APP_NAME"]!)"

        # Number of seconds to wait (seconds) for the Self Service custon icon
          SELF_SERVICE_CUSTOM_WAIT=\(keys.settingsDict["SELF_SERVICE_CUSTOM_WAIT"]!)


        #########################################################################################
        # EULA Variables to Modify
        #########################################################################################
        # EULA configuration
          EULA_ENABLED=\(keys.settingsDict["EULA_ENABLED"]!) # Set variable to true or false

        # EULA status bar text
          EULA_STATUS="\(keys.settingsDict["EULA_STATUS"]!)"

        # EULA button text on the main screen
          EULA_BUTTON="\(keys.settingsDict["EULA_BUTTON"]!)"

        # EULA Screen Title
          EULA_MAIN_TITLE="\(keys.settingsDict["EULA_MAIN_TITLE"]!)"

        # EULA Subtitle
          EULA_SUBTITLE="\(keys.settingsDict["EULA_SUBTITLE"]!)"

        # Path to the EULA file you would like the user to read and agree to. It is
        # best to package this up with Composer or another tool and deliver it to a
        # shared area like /Users/Shared/
          EULA_FILE_PATH="\(keys.settingsDict["EULA_FILE_PATH"]!)"

        #########################################################################################
        # Registration Variables to Modify
        #########################################################################################
        # Registration window configuration
          REGISTRATION_ENABLED=\(keys.settingsDict["REGISTRATION_ENABLED"]!) # Set variable to true or false

        # Registration window title
         REGISTRATION_TITLE="\(keys.settingsDict["REGISTRATION_TITLE"]!)"

        # Registration status bar text
         REGISTRATION_STATUS="\(keys.settingsDict["REGISTRATION_STATUS"]!)"

        # Registration window submit or finish button text
         REGISTRATION_BUTTON="\(keys.settingsDict["REGISTRATION_BUTTON"]!)"

        # The text and pick list sections below will write the following lines out for
        # end users. Use the variables below to configure what the sentence says
        # Ex: Setting Computer Name to macBook0132
         REGISTRATION_BEGIN_WORD="\(keys.settingsDict["REGISTRATION_BEGIN_WORD"]!)"
         REGISTRATION_MIDDLE_WORD="\(keys.settingsDict["REGISTRATION_MIDDLE_WORD"]!)"

        # Registration window can have up to two text fields. Leaving the text display
        # variable empty will hide the input box. Display text is to the side of the
        # input and placeholder text is the gray text inside the input box.
        # Registration window can have up to four dropdown / pick list inputs. Leaving
        # the pick display variable empty will hide the dropdown / pick list.

        # First Text Field
        #######################################################################################
        # Text Field Label
          REG_TEXT_LABEL_1="\(keys.settingsDict["REG_TEXT_LABEL_1"]!)"

        # Place Holder Text
          REG_TEXT_LABEL_1_PLACEHOLDER="\(keys.settingsDict["REG_TEXT_LABEL_1_PLACEHOLDER"]!)"

        # Optional flag for making the field an optional input for end user
          REG_TEXT_LABEL_1_OPTIONAL="\(keys.settingsDict["REG_TEXT_LABEL_1_OPTIONAL"]!.lowercased())" # Set variable to true or false

        # Help Bubble for Input. If title left blank, this will not appear
          REG_TEXT_LABEL_1_HELP_TITLE="\(keys.settingsDict["REG_TEXT_LABEL_1_HELP_TITLE"]!)"
          REG_TEXT_LABEL_1_HELP_TEXT="\(keys.settingsDict["REG_TEXT_LABEL_1_HELP_TEXT"]!)"

        # Logic below was put in this section rather than in core code as folks may
        # want to change what the field does. This is a function that gets called
        # when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
          REG_TEXT_LABEL_1_LOGIC (){
            REG_TEXT_LABEL_1_VALUE=$(/usr/bin/defaults read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_TEXT_LABEL_1")
            if [ "$REG_TEXT_LABEL_1_OPTIONAL" = true ] && [ "$REG_TEXT_LABEL_1_VALUE" = "" ]; then
              echo "Status: $REG_TEXT_LABEL_1 was left empty. Skipping..." >> "$DEP_NOTIFY_LOG"
              echo "$(date "+%a %h %d %H:%M:%S"): $REG_TEXT_LABEL_1 was set to optional and was left empty. Skipping..." >> "$DEP_NOTIFY_DEBUG"
              sleep 5
            else
              echo "Status: $REGISTRATION_BEGIN_WORD $REG_TEXT_LABEL_1 $REGISTRATION_MIDDLE_WORD $REG_TEXT_LABEL_1_VALUE" >> "$DEP_NOTIFY_LOG"
              if [ "$TESTING_MODE" = true ]; then
                sleep 10
              else
                "$JAMF_BINARY" setComputerName -name "$REG_TEXT_LABEL_1_VALUE"
                sleep 5
              fi
            fi
          }

        # Second Text Field
        #######################################################################################
        # Text Field Label
          REG_TEXT_LABEL_2="\(keys.settingsDict["REG_TEXT_LABEL_2"]!)"

        # Place Holder Text
          REG_TEXT_LABEL_2_PLACEHOLDER="\(keys.settingsDict["REG_TEXT_LABEL_2_PLACEHOLDER"]!)"

        # Optional flag for making the field an optional input for end user
          REG_TEXT_LABEL_2_OPTIONAL="\(keys.settingsDict["REG_TEXT_LABEL_2_OPTIONAL"]!)" # Set variable to true or false

        # Help Bubble for Input. If title left blank, this will not appear
          REG_TEXT_LABEL_2_HELP_TITLE="\(keys.settingsDict["REG_TEXT_LABEL_2_HELP_TITLE"]!)"
          REG_TEXT_LABEL_2_HELP_TEXT="\(keys.settingsDict["REG_TEXT_LABEL_2_HELP_TEXT"]!)"

        # Logic below was put in this section rather than in core code as folks may
        # want to change what the field does. This is a function that gets called
        # when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
          REG_TEXT_LABEL_2_LOGIC (){
            REG_TEXT_LABEL_2_VALUE=$(/usr/bin/defaults read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_TEXT_LABEL_2")
            if [ "$REG_TEXT_LABEL_2_OPTIONAL" = true ] && [ "$REG_TEXT_LABEL_2_VALUE" = "" ]; then
              echo "Status: $REG_TEXT_LABEL_2 was left empty. Skipping..." >> "$DEP_NOTIFY_LOG"
              echo "$(date "+%a %h %d %H:%M:%S"): $REG_TEXT_LABEL_2 was set to optional and was left empty. Skipping..." >> "$DEP_NOTIFY_DEBUG"
              sleep 5
            else
              echo "Status: $REGISTRATION_BEGIN_WORD $REG_TEXT_LABEL_2 $REGISTRATION_MIDDLE_WORD $REG_TEXT_LABEL_2_VALUE" >> "$DEP_NOTIFY_LOG"
              if [ "$TESTING_MODE" = true ]; then
                 sleep 10
              else
                "$JAMF_BINARY" recon -assetTag "$REG_TEXT_LABEL_2_VALUE"
              fi
            fi
          }

        # Popup 1
        #######################################################################################
        # Label for the popup
          REG_POPUP_LABEL_1="\(keys.settingsDict["REG_POPUP_LABEL_1"]!)"

        # Array of options for the user to select
          REG_POPUP_LABEL_1_OPTIONS=(
            \(keys.settingsDict["REG_POPUP_LABEL_1_OPTIONS"]!)
          )

        # Help Bubble for Input. If title left blank, this will not appear
          REG_POPUP_LABEL_1_HELP_TITLE="Building Dropdown Field"
          REG_POPUP_LABEL_1_HELP_TEXT="Please choose the appropriate building for where you normally work. This is important for inventory purposes."

        # Logic below was put in this section rather than in core code as folks may
        # want to change what the field does. This is a function that gets called
        # when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
          REG_POPUP_LABEL_1_LOGIC (){
            REG_POPUP_LABEL_1_VALUE=$(/usr/bin/defaults read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_1")
            echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_1 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_1_VALUE" >> "$DEP_NOTIFY_LOG"
            if [ "$TESTING_MODE" = true ]; then
               sleep 10
            else
              "$JAMF_BINARY" recon -building "$REG_POPUP_LABEL_1_VALUE"
            fi
          }

        # Popup 2
        #######################################################################################
        # Label for the popup
          REG_POPUP_LABEL_2="\(keys.settingsDict["REG_POPUP_LABEL_2"]!)"

        # Array of options for the user to select
          REG_POPUP_LABEL_2_OPTIONS=(
            \(keys.settingsDict["REG_POPUP_LABEL_2_OPTIONS"]!)
          )

        # Help Bubble for Input. If title left blank, this will not appear
          REG_POPUP_LABEL_2_HELP_TITLE="Department Dropdown Field"
          REG_POPUP_LABEL_2_HELP_TEXT="Please choose the appropriate department for where you normally work. This is important for inventory purposes."

        # Logic below was put in this section rather than in core code as folks may
        # want to change what the field does. This is a function that gets called
        # when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
          REG_POPUP_LABEL_2_LOGIC (){
            REG_POPUP_LABEL_2_VALUE=$(/usr/bin/defaults read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_2")
            echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_2 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_2_VALUE" >> "$DEP_NOTIFY_LOG"
            if [ "$TESTING_MODE" = true ]; then
               sleep 10
            else
              "$JAMF_BINARY" recon -department "$REG_POPUP_LABEL_2_VALUE"
            fi
          }

        # Popup 3 - Code is here but currently unused
        #######################################################################################
        # Label for the popup
          REG_POPUP_LABEL_3="\(keys.settingsDict["REG_POPUP_LABEL_3"]!)"

        # Array of options for the user to select
          REG_POPUP_LABEL_3_OPTIONS=(
            \(keys.settingsDict["REG_POPUP_LABEL_3_OPTIONS"]!)
          )

        # Help Bubble for Input. If title left blank, this will not appear
          REG_POPUP_LABEL_3_HELP_TITLE="Dropdown 3 Field"
          REG_POPUP_LABEL_3_HELP_TEXT="This dropdown is currently not in use. All code is here ready for you to use. It can also be hidden by removing the contents of the REG_POPUP_LABEL_3 variable."

        # Logic below was put in this section rather than in core code as folks may
        # want to change what the field does. This is a function that gets called
        # when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
          REG_POPUP_LABEL_3_LOGIC (){
            REG_POPUP_LABEL_3_VALUE=$(/usr/bin/defaults read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_3")
            echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_3 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_3_VALUE" >> "$DEP_NOTIFY_LOG"
            if [ "$TESTING_MODE" = true ]; then
              sleep 10
            else
              sleep 10
            fi
          }

        # Popup 4 - Code is here but currently unused
        #######################################################################################
        # Label for the popup
          REG_POPUP_LABEL_4="\(keys.settingsDict["REG_POPUP_LABEL_4"]!)"

        # Array of options for the user to select
          REG_POPUP_LABEL_4_OPTIONS=(
            \(keys.settingsDict["REG_POPUP_LABEL_4_OPTIONS"]!)
          )

        # Help Bubble for Input. If title left blank, this will not appear
          REG_POPUP_LABEL_4_HELP_TITLE="Dropdown 4 Field"
          REG_POPUP_LABEL_4_HELP_TEXT="This dropdown is currently not in use. All code is here ready for you to use. It can also be hidden by removing the contents of the REG_POPUP_LABEL_4 variable."

        # Logic below was put in this section rather than in core code as folks may
        # want to change what the field does. This is a function that gets called
        # when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
          REG_POPUP_LABEL_4_LOGIC (){
            REG_POPUP_LABEL_4_VALUE=$(/usr/bin/defaults read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_4")
            echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_4 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_4_VALUE" >> "$DEP_NOTIFY_LOG"
            if [ "$TESTING_MODE" = true ]; then
              sleep 10
            else
              sleep 10
            fi
          }

        #########################################################################################
        #########################################################################################
        # Core Script Logic - Don't Change Without Major Testing
        #########################################################################################
        #########################################################################################

        # Variables for File Paths
          JAMF_BINARY="/usr/local/bin/jamf"
          FDE_SETUP_BINARY="/usr/bin/fdesetup"
          DEP_NOTIFY_APP="/Applications/Utilities/DEPNotify.app"
          DEP_NOTIFY_LOG="/var/tmp/depnotify.log"
          DEP_NOTIFY_DEBUG="/var/tmp/depnotifyDebug.log"
          DEP_NOTIFY_DONE="/var/tmp/com.depnotify.provisioning.done"

        # Pulling from Policy parameters to allow true/false flags to be set. More info
        # can be found on https://www.jamf.com/jamf-nation/articles/146/script-parameters
        # These will override what is specified in the script above.
          # Testing Mode
            if [ "$4" != "" ]; then TESTING_MODE="$4"; fi
          # Fullscreen Mode
            if [ "$5" != "" ]; then FULLSCREEN="$5"; fi
          # No Sleep / Caffeinate Mode
            if [ "$6" != "" ]; then NO_SLEEP="$6"; fi
          # Self Service Custom Branding
            if [ "$7" != "" ]; then SELF_SERVICE_CUSTOM_BRANDING="$7"; fi
          # Complete method dropdown or main screen
            if [ "$8" != "" ]; then COMPLETE_METHOD_DROPDOWN_ALERT="$8"; fi
          # EULA Mode
            if [ "$9" != "" ]; then EULA_ENABLED="$9"; fi
          # Registration Mode
            if [ "${10}" != "" ]; then REGISTRATION_ENABLED="${10}"; fi

        # Standard Testing Mode Enhancements
          if [ "$TESTING_MODE" = true ]; then
            # Removing old config file if present (Testing Mode Only)
              if [ -f "$DEP_NOTIFY_LOG" ]; then rm "$DEP_NOTIFY_LOG"; fi
              if [ -f "$DEP_NOTIFY_DONE" ]; then rm "$DEP_NOTIFY_DONE"; fi
              if [ -f "$DEP_NOTIFY_DEBUG" ]; then rm "$DEP_NOTIFY_DEBUG"; fi
            # Setting Quit Key set to command + control + x (Testing Mode Only)
              echo "Command: QuitKey: x" >> "$DEP_NOTIFY_LOG"
          fi

        # Validating true/false flags
          if [ "$TESTING_MODE" != true ] && [ "$TESTING_MODE" != false ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): Testing configuration not set properly. Currently set to $TESTING_MODE. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
            exit 1
          fi
          if [ "$FULLSCREEN" != true ] && [ "$FULLSCREEN" != false ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): Fullscreen configuration not set properly. Currently set to $FULLSCREEN. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
            exit 1
          fi
          if [ "$NO_SLEEP" != true ] && [ "$NO_SLEEP" != false ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): Sleep configuration not set properly. Currently set to $NO_SLEEP. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
            exit 1
          fi
          if [ "$SELF_SERVICE_CUSTOM_BRANDING" != true ] && [ "$SELF_SERVICE_CUSTOM_BRANDING" != false ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): Self Service Custom Branding configuration not set properly. Currently set to $SELF_SERVICE_CUSTOM_BRANDING. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
            exit 1
          fi
          if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" != true ] && [ "$COMPLETE_METHOD_DROPDOWN_ALERT" != false ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): Completion alert method not set properly. Currently set to $COMPLETE_METHOD_DROPDOWN_ALERT. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
            exit 1
          fi
          if [ "$EULA_ENABLED" != true ] && [ "$EULA_ENABLED" != false ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): EULA configuration not set properly. Currently set to $EULA_ENABLED. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
            exit 1
          fi
          if [ "$REGISTRATION_ENABLED" != true ] && [ "$REGISTRATION_ENABLED" != false ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): Registration configuration not set properly. Currently set to $REGISTRATION_ENABLED. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
            exit 1
          fi

        # Run DEP Notify will run after Apple Setup Assistant
          SETUP_ASSISTANT_PROCESS=$(pgrep -l "Setup Assistant")
          until [ "$SETUP_ASSISTANT_PROCESS" = "" ]; do
            echo "$(date "+%a %h %d %H:%M:%S"): Setup Assistant Still Running. PID $SETUP_ASSISTANT_PROCESS." >> "$DEP_NOTIFY_DEBUG"
            sleep 1
            SETUP_ASSISTANT_PROCESS=$(pgrep -l "Setup Assistant")
          done

        # Checking to see if the Finder is running now before continuing. This can help
        # in scenarios where an end user is not configuring the device.
          FINDER_PROCESS=$(pgrep -l "Finder")
          until [ "$FINDER_PROCESS" != "" ]; do
            echo "$(date "+%a %h %d %H:%M:%S"): Finder process not found. Assuming device is at login screen." >> "$DEP_NOTIFY_DEBUG"
            sleep 1
            FINDER_PROCESS=$(pgrep -l "Finder")
          done

        # After the Apple Setup completed. Now safe to grab the current user.
          CURRENT_USER=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\\n");')
          CURRENT_USER_ID=$(id -u $CURRENT_USER)
          echo "$(date "+%a %h %d %H:%M:%S"): Current user set to $CURRENT_USER (id: $CURRENT_USER_ID)." >> "$DEP_NOTIFY_DEBUG"

        # Stop DEPNotify if there was already a DEPNotify window running (from a PreStage package postinstall script).
         PREVIOUS_DEP_NOTIFY_PROCESS=$(pgrep -l "DEPNotify" | cut -d " " -f1)
          until [ "$PREVIOUS_DEP_NOTIFY_PROCESS" = "" ]; do
            echo "$(date "+%a %h %d %H:%M:%S"): Stopping the previously-opened instance of DEPNotify." >> "$DEP_NOTIFY_DEBUG"
            kill $PREVIOUS_DEP_NOTIFY_PROCESS
            PREVIOUS_DEP_NOTIFY_PROCESS=$(pgrep -l "DEPNotify" | cut -d " " -f1)
          done
          
         # Stop BigHonkingText if it's running (from a PreStage package postinstall script).
         BIG_HONKING_TEXT_PROCESS=$(pgrep -l "BigHonkingText" | cut -d " " -f1)
          until [ "$BIG_HONKING_TEXT_PROCESS" = "" ]; do
            echo "$(date "+%a %h %d %H:%M:%S"): Stopping the previously-opened instance of BigHonkingText." >> "$DEP_NOTIFY_DEBUG"
            kill $BIG_HONKING_TEXT_PROCESS
            BIG_HONKING_TEXT_PROCESS=$(pgrep -l "BigHonkingText" | cut -d " " -f1)
          done

        # Adding Check and Warning if Testing Mode is off and BOM files exist
          if [[ ( -f "$DEP_NOTIFY_LOG" || -f "$DEP_NOTIFY_DONE" ) && "$TESTING_MODE" = false ]]; then
            echo "$(date "+%a %h %d %H:%M:%S"): TESTING_MODE set to false but config files were found in /var/tmp. Letting user know and exiting." >> "$DEP_NOTIFY_DEBUG"
            mv "$DEP_NOTIFY_LOG" "/var/tmp/depnotify_old.log"
            echo "Command: MainTitle: $ERROR_BANNER_TITLE" >> "$DEP_NOTIFY_LOG"
            echo "Command: MainText: $ERROR_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
            echo "Status: $ERROR_STATUS" >> "$DEP_NOTIFY_LOG"
            launchctl asuser $CURRENT_USER_ID open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG"
            sleep 5
            exit 1
          fi

        # If SELF_SERVICE_CUSTOM_BRANDING is set to true. Loading the updated icon
          if [ "$SELF_SERVICE_CUSTOM_BRANDING" = true ]; then
            open -a "/Applications/$SELF_SERVICE_APP_NAME" --hide

            # Loop waiting on the branding image to properly show in the users library - wait up to 20 seconds
             SELF_SERVICE_COUNTER=0
             CUSTOM_BRANDING_PNG="/Users/$CURRENT_USER/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"

             until [ -f "$CUSTOM_BRANDING_PNG" ]; do
               echo "$(date "+%a %h %d %H:%M:%S"): Waiting for branding image from Jamf Pro." >> "$DEP_NOTIFY_DEBUG"
                sleep 1
                (( SELF_SERVICE_COUNTER++ ))
                if [ $SELF_SERVICE_COUNTER -gt $SELF_SERVICE_CUSTOM_WAIT ];then
                    CUSTOM_BRANDING_PNG="/Applications/Self Service.app/Contents/Resources/AppIcon.icns"
                    break
                fi
             done

            # Setting Banner Image for DEP Notify to Self Service Custom Branding
             BANNER_IMAGE_PATH="$CUSTOM_BRANDING_PNG"

            # Closing Self Service
             SELF_SERVICE_PID=$(pgrep -l "Self Service" | cut -d' ' -f1)
             echo "$(date "+%a %h %d %H:%M:%S"): Self Service custom branding icon has been loaded. Killing Self Service PID $SELF_SERVICE_PID." >>  "$DEP_NOTIFY_DEBUG"
             kill "$SELF_SERVICE_PID"
        elif [ -f "$BANNER_IMAGE_PATH" ];then
             BANNER_IMAGE_PATH="/Applications/Self Service.app/Contents/Resources/AppIcon.icns"
        fi

        # Setting custom image if specified
          if [ "$BANNER_IMAGE_PATH" != "" ]; then  echo "Command: Image: $BANNER_IMAGE_PATH" >> "$DEP_NOTIFY_LOG"; fi

        # Setting custom title if specified
          if [ "$BANNER_TITLE" != "" ]; then echo "Command: MainTitle: $BANNER_TITLE" >> "$DEP_NOTIFY_LOG"; fi

        # Setting custom main text if specified
          if [ "$MAIN_TEXT" != "" ]; then echo "Command: MainText: $MAIN_TEXT" >> "$DEP_NOTIFY_LOG"; fi

        # General Plist Configuration
        # Calling function to set the INFO_PLIST_PATH
          INFO_PLIST_WRAPPER

        # The plist information below
          DEP_NOTIFY_CONFIG_PLIST="/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotify.plist"

        # If testing mode is on, this will remove some old configuration files
          if [ "$TESTING_MODE" = true ] && [ -f "$DEP_NOTIFY_CONFIG_PLIST" ]; then rm "$DEP_NOTIFY_CONFIG_PLIST"; fi
          if [ "$TESTING_MODE" = true ] && [ -f "$DEP_NOTIFY_USER_INPUT_PLIST" ]; then rm "$DEP_NOTIFY_USER_INPUT_PLIST"; fi

        # Setting default path to the plist which stores all the user completed info
          /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" pathToPlistFile "$DEP_NOTIFY_USER_INPUT_PLIST"

        # Setting status text alignment
          /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" statusTextAlignment "$STATUS_TEXT_ALIGN"

        # Setting help button
          if [ "$HELP_BUBBLE_TITLE" != "" ]; then
            /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" helpBubble -array-add "$HELP_BUBBLE_TITLE"
            /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" helpBubble -array-add "$HELP_BUBBLE_BODY"
          fi

        # EULA Configuration
          if [ "$EULA_ENABLED" =  true ]; then
            DEP_NOTIFY_EULA_DONE="/var/tmp/com.depnotify.agreement.done"

            # If testing mode is on, this will remove EULA specific configuration files
              if [ "$TESTING_MODE" = true ] && [ -f "$DEP_NOTIFY_EULA_DONE" ]; then rm "$DEP_NOTIFY_EULA_DONE"; fi

            # Writing title, subtitle, and EULA txt location to plist
              /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" EULAMainTitle "$EULA_MAIN_TITLE"
              /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" EULASubTitle "$EULA_SUBTITLE"
              /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" pathToEULA "$EULA_FILE_PATH"

            # Setting ownership of EULA file
              chown "$CURRENT_USER:staff" "$EULA_FILE_PATH"
              chmod 444 "$EULA_FILE_PATH"
          fi

        # Registration Plist Configuration
          if [ "$REGISTRATION_ENABLED" = true ]; then
            DEP_NOTIFY_REGISTER_DONE="/var/tmp/com.depnotify.registration.done"

            # If testing mode is on, this will remove registration specific configuration files
              if [ "$TESTING_MODE" = true ] && [ -f "$DEP_NOTIFY_REGISTER_DONE" ]; then rm "$DEP_NOTIFY_REGISTER_DONE"; fi

            # Main Window Text Configuration
              /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" registrationMainTitle "$REGISTRATION_TITLE"
              /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" registrationButtonLabel "$REGISTRATION_BUTTON"
              /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" registrationPicturePath "$BANNER_IMAGE_PATH"

            # First Text Box Configuration
              if [ "$REG_TEXT_LABEL_1" != "" ]; then
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField1Label "$REG_TEXT_LABEL_1"
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField1Placeholder "$REG_TEXT_LABEL_1_PLACEHOLDER"
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField1IsOptional "$REG_TEXT_LABEL_1_OPTIONAL"
                # Code for showing the help box if configured
                  if [ "$REG_TEXT_LABEL_1_HELP_TITLE" != "" ]; then
                      /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField1Bubble -array-add "$REG_TEXT_LABEL_1_HELP_TITLE"
                      /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField1Bubble -array-add "$REG_TEXT_LABEL_1_HELP_TEXT"
                  fi
              fi

            # Second Text Box Configuration
              if [ "$REG_TEXT_LABEL_2" != "" ]; then
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField2Label "$REG_TEXT_LABEL_2"
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField2Placeholder "$REG_TEXT_LABEL_2_PLACEHOLDER"
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField2IsOptional "$REG_TEXT_LABEL_2_OPTIONAL"
                # Code for showing the help box if configured
                  if [ "$REG_TEXT_LABEL_2_HELP_TITLE" != "" ]; then
                      /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField2Bubble -array-add "$REG_TEXT_LABEL_2_HELP_TITLE"
                      /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" textField2Bubble -array-add "$REG_TEXT_LABEL_2_HELP_TEXT"
                  fi
              fi

            # Popup 1
              if [ "$REG_POPUP_LABEL_1" != "" ]; then
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton1Label "$REG_POPUP_LABEL_1"
                # Code for showing the help box if configured
                  if [ "$REG_POPUP_LABEL_1_HELP_TITLE" != "" ]; then
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu1Bubble -array-add "$REG_POPUP_LABEL_1_HELP_TITLE"
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu1Bubble -array-add "$REG_POPUP_LABEL_1_HELP_TEXT"
                  fi
                # Code for adding the items from the array above into the plist
                  for REG_POPUP_LABEL_1_OPTION in "${REG_POPUP_LABEL_1_OPTIONS[@]}"; do
                     /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton1Content -array-add "$REG_POPUP_LABEL_1_OPTION"
                  done
              fi

            # Popup 2
              if [ "$REG_POPUP_LABEL_2" != "" ]; then
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton2Label "$REG_POPUP_LABEL_2"
                # Code for showing the help box if configured
                  if [ "$REG_POPUP_LABEL_2_HELP_TITLE" != "" ]; then
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu2Bubble -array-add "$REG_POPUP_LABEL_2_HELP_TITLE"
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu2Bubble -array-add "$REG_POPUP_LABEL_2_HELP_TEXT"
                  fi
                # Code for adding the items from the array above into the plist
                  for REG_POPUP_LABEL_2_OPTION in "${REG_POPUP_LABEL_2_OPTIONS[@]}"; do
                     /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton2Content -array-add "$REG_POPUP_LABEL_2_OPTION"
                  done
              fi

            # Popup 3
              if [ "$REG_POPUP_LABEL_3" != "" ]; then
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton3Label "$REG_POPUP_LABEL_3"
                # Code for showing the help box if configured
                  if [ "$REG_POPUP_LABEL_3_HELP_TITLE" != "" ]; then
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu3Bubble -array-add "$REG_POPUP_LABEL_3_HELP_TITLE"
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu3Bubble -array-add "$REG_POPUP_LABEL_3_HELP_TEXT"
                  fi
                # Code for adding the items from the array above into the plist
                  for REG_POPUP_LABEL_3_OPTION in "${REG_POPUP_LABEL_3_OPTIONS[@]}"; do
                     /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton3Content -array-add "$REG_POPUP_LABEL_3_OPTION"
                  done
              fi

            # Popup 4
              if [ "$REG_POPUP_LABEL_4" != "" ]; then
                /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton4Label "$REG_POPUP_LABEL_4"
                # Code for showing the help box if configured
                  if [ "$REG_POPUP_LABEL_4_HELP_TITLE" != "" ]; then
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu4Bubble -array-add "$REG_POPUP_LABEL_4_HELP_TITLE"
                    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupMenu4Bubble -array-add "$REG_POPUP_LABEL_4_HELP_TEXT"
                  fi
                # Code for adding the items from the array above into the plist
                  for REG_POPUP_LABEL_4_OPTION in "${REG_POPUP_LABEL_4_OPTIONS[@]}"; do
                     /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" popupButton4Content -array-add "$REG_POPUP_LABEL_4_OPTION"
                  done
              fi
          fi

        # Changing Ownership of the plist file
          chown "$CURRENT_USER":staff "$DEP_NOTIFY_CONFIG_PLIST"
          chmod 600 "$DEP_NOTIFY_CONFIG_PLIST"

        # Opening the app after initial configuration
          if [ "$FULLSCREEN" = true ]; then
            launchctl asuser $CURRENT_USER_ID open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG" -fullScreen
          elif [ "$FULLSCREEN" = false ]; then
            launchctl asuser $CURRENT_USER_ID open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG"
          fi

        # Grabbing the DEP Notify Process ID for use later
          DEP_NOTIFY_PROCESS=$(pgrep -l "DEPNotify" | cut -d " " -f1)
          until [ "$DEP_NOTIFY_PROCESS" != "" ]; do
            echo "$(date "+%a %h %d %H:%M:%S"): Waiting for DEPNotify to start to gather the process ID." >> "$DEP_NOTIFY_DEBUG"
            sleep 1
            DEP_NOTIFY_PROCESS=$(pgrep -l "DEPNotify" | cut -d " " -f1)
          done

        # Using Caffeinate binary to keep the computer awake if enabled
          if [ "$NO_SLEEP" = true ]; then
            echo "$(date "+%a %h %d %H:%M:%S"): Caffeinating DEP Notify process. Process ID: $DEP_NOTIFY_PROCESS" >> "$DEP_NOTIFY_DEBUG"
            caffeinate -disu -w "$DEP_NOTIFY_PROCESS"&
          fi

        # Adding an alert prompt to let admins know that the script is in testing mode
          if [ "$TESTING_MODE" = true ]; then
            echo "Command: Alert: DEP Notify is in TESTING_MODE. Script will not run Policies or other commands that make change to this computer."  >> "$DEP_NOTIFY_LOG"
          fi

        # Adding nice text and a brief pause for prettiness
          echo "Status: $INITAL_START_STATUS" >> "$DEP_NOTIFY_LOG"
          sleep 5

        # Setting the status bar
          # Counter is for making the determinate look nice. Starts at one and adds
          # more based on EULA, register, or other options.
            ADDITIONAL_OPTIONS_COUNTER=1
            if [ "$EULA_ENABLED" = true ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi
            if [ "$REGISTRATION_ENABLED" = true ]; then ((ADDITIONAL_OPTIONS_COUNTER++))
              if [ "$REG_TEXT_LABEL_1" != "" ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi
              if [ "$REG_TEXT_LABEL_2" != "" ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi
              if [ "$REG_POPUP_LABEL_1" != "" ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi
              if [ "$REG_POPUP_LABEL_2" != "" ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi
              if [ "$REG_POPUP_LABEL_3" != "" ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi
              if [ "$REG_POPUP_LABEL_4" != "" ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi
            fi

        # Checking policy array and adding the count from the additional options above.
          ARRAY_LENGTH="$((${#POLICY_ARRAY[@]}+ADDITIONAL_OPTIONS_COUNTER))"
          echo "Command: Determinate: $ARRAY_LENGTH" >> "$DEP_NOTIFY_LOG"

        # EULA Window Display Logic
          if [ "$EULA_ENABLED" = true ]; then
            echo "Status: $EULA_STATUS" >> "$DEP_NOTIFY_LOG"
            echo "Command: ContinueButtonEULA: $EULA_BUTTON" >> "$DEP_NOTIFY_LOG"
            while [ ! -f "$DEP_NOTIFY_EULA_DONE" ]; do
              echo "$(date "+%a %h %d %H:%M:%S"): Waiting for user to accept EULA." >> "$DEP_NOTIFY_DEBUG"
              sleep 1
            done
          fi

        # Registration Window Display Logic
          if [ "$REGISTRATION_ENABLED" = true ]; then
            echo "Status: $REGISTRATION_STATUS" >> "$DEP_NOTIFY_LOG"
            echo "Command: ContinueButtonRegister: $REGISTRATION_BUTTON" >> "$DEP_NOTIFY_LOG"
            while [ ! -f "$DEP_NOTIFY_REGISTER_DONE" ]; do
              echo "$(date "+%a %h %d %H:%M:%S"): Waiting for user to complete registration." >> "$DEP_NOTIFY_DEBUG"
              sleep 1
            done
            # Running Logic For Each Registration Box
              if [ "$REG_TEXT_LABEL_1" != "" ]; then REG_TEXT_LABEL_1_LOGIC; fi
              if [ "$REG_TEXT_LABEL_2" != "" ]; then REG_TEXT_LABEL_2_LOGIC; fi
              if [ "$REG_POPUP_LABEL_1" != "" ]; then REG_POPUP_LABEL_1_LOGIC; fi
              if [ "$REG_POPUP_LABEL_2" != "" ]; then REG_POPUP_LABEL_2_LOGIC; fi
              if [ "$REG_POPUP_LABEL_3" != "" ]; then REG_POPUP_LABEL_3_LOGIC; fi
              if [ "$REG_POPUP_LABEL_4" != "" ]; then REG_POPUP_LABEL_4_LOGIC; fi
          fi

        # Loop to run policies
          for POLICY in "${POLICY_ARRAY[@]}"; do
            echo "Status: $(echo "$POLICY" | cut -d ',' -f1)" >> "$DEP_NOTIFY_LOG"
            if [ "$TESTING_MODE" = true ]; then
              sleep 10
            elif [ "$TESTING_MODE" = false ]; then
              "$JAMF_BINARY" policy -id "$(echo "$POLICY" | cut -d ',' -f2)"
            fi
          done

        # Nice completion text
          echo "Status: $INSTALL_COMPLETE_TEXT" >> "$DEP_NOTIFY_LOG"

        # Check to see if FileVault Deferred enablement is active
          FV_DEFERRED_STATUS=$($FDE_SETUP_BINARY status | grep "Deferred" | cut -d ' ' -f6)

        # Logic to log user out if FileVault is detected. Otherwise, app will close.
            if [ "$FV_DEFERRED_STATUS" = "active" ] && [ "$TESTING_MODE" = true ]; then
              if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" = true ]; then
                echo "Command: Quit: This is typically where your FV_LOGOUT_TEXT would be displayed. However, TESTING_MODE is set to true and FileVault deferred status is on." >> "$DEP_NOTIFY_LOG"
              else
                echo "Command: MainText: TESTING_MODE is set to true and FileVault deferred status is on. Button effect is quit instead of logout. \\n \\n $FV_COMPLETE_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
                echo "Command: ContinueButton: Test $FV_COMPLETE_BUTTON_TEXT" >> "$DEP_NOTIFY_LOG"
              fi
            elif [ "$FV_DEFERRED_STATUS" = "active" ] && [ "$TESTING_MODE" = false ]; then
              if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" = true ]; then
                echo "Command: Logout: $FV_ALERT_TEXT" >> "$DEP_NOTIFY_LOG"
              else
                echo "Command: MainText: $FV_COMPLETE_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
                echo "Command: ContinueButtonLogout: $FV_COMPLETE_BUTTON_TEXT" >> "$DEP_NOTIFY_LOG"
              fi
            else
              if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" = true ]; then
                echo "Command: Quit: $COMPLETE_ALERT_TEXT" >> "$DEP_NOTIFY_LOG"
              else
                echo "Command: MainText: $COMPLETE_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
                echo "Command: ContinueButton: $COMPLETE_BUTTON_TEXT" >> "$DEP_NOTIFY_LOG"
              fi
            fi

        exit 0
        """
        if let _ = (sender as? NSButton)?.title {
            let saveDialog = NSSavePanel()
            saveDialog.canCreateDirectories = true
            saveDialog.nameFieldStringValue = scriptName
            saveDialog.beginSheetModal(for: self.view.window!){ result in
                if result == .OK {
                    
                    scriptName = saveDialog.nameFieldStringValue
                    exportURL = saveDialog.url!
    //                print("fileName", scriptName)
                    do {
                        try currentScript.write(to: exportURL, atomically: true, encoding: .utf8)
                    } catch {
                        print("failed to write to \(scriptName).")
                    }
                    
                }
            }
        } else {
            currentScript = currentScript.replacingOccurrences(of: "TESTING_MODE=false # Set variable to true or false", with: "TESTING_MODE=true # Set variable to true or false")
            currentScript = currentScript.replacingOccurrences(of: "DEP_NOTIFY_APP=\"/Applications/Utilities/DEPNotify.app\"", with: "DEP_NOTIFY_APP=\"\(DEPNotifyPath!.absoluteString.pathToString)\"")
//            currentScript = currentScript.replacingOccurrences(of: "DEP_NOTIFY_LOG=\"/var/tmp/depnotify.log\"", with: "DEP_NOTIFY_LOG=\"/var/tmp/depnotifyPreview.log\"")
            do {
                let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                let previewPath = downloadsDirectory.appendingPathComponent("DEPNotifyPreview.sh")
                try currentScript.write(to: previewPath, atomically: true, encoding: .utf8)
                
                // clean up old files if present
                do {
                    let directoryContent = try fileManager.contentsOfDirectory(at: URL(string: "/private/tmp")!, includingPropertiesForKeys: [], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
                    for url in directoryContent {
                        if url.absoluteString.contains("depnotify") {
                            try fileManager.removeItem(at: url)
                        }
                    }
                }
                catch {
                    Alert().display(header: "Attention", message: "Unable to remove depnotify files from /private/tmp, remove manually.")
                    preview_Button.isEnabled = true
                    return
                }
                do {
                    let homePath = NSHomeDirectory().pathToString
                    let directoryContent = try fileManager.contentsOfDirectory(at: URL(string: "\(homePath)/Library/Preferences/")!, includingPropertiesForKeys: [], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
                    for url in directoryContent {
                        if url.absoluteString.contains("menu.nomad.DEPNotify") {
                            try fileManager.removeItem(at: url)
                        }
                    }
                }
                catch {
                    Alert().display(header: "Attention", message: "Unable to remove menu.nomad.DEPNotify* files from ~/Library/Preferences, remove manually.")
                    preview_Button.isEnabled = true
                    return
                }
                _ = myExitCode(cmd: "/usr/bin/killall", args: "cfprefsd")
                
                // run the script
                if myExitCode(cmd: "/bin/bash", args: previewPath.absoluteString.pathToString) == 0 {
                    _ = myExitCode(cmd: DEPNotifyBinary, args: "")
                } else {
                    // script failed to run
                }
            } catch {
                print("failed to write to \(scriptName).")
            }
            preview_Button.isEnabled = true
        }
    }   // @IBAction func generateScript_Action
    
    @IBAction func preview_Button(_ sender: Any) {
        preview_Button.isEnabled = false
        if !fileManager.fileExists(atPath: "/Applications/Utilities/DEPNotify.app") {
            // Locate DEPNotify
            DispatchQueue.main.async {
                let openPanel = NSOpenPanel()
            
                openPanel.canChooseDirectories = false
                openPanel.canChooseFiles       = true
                openPanel.allowedFileTypes     = ["app"]
            
                openPanel.begin { [self] (result) in
                    if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                        DEPNotifyPath   = openPanel.url
                        DEPNotifyBinary = (DEPNotifyPath?.absoluteString.pathToString)!+"/Contents/MacOS/DEPNotify"
                        if !fileManager.fileExists(atPath: self.DEPNotifyBinary) {
                            print("This does not seem to be the DEPNotify app")
                            Alert().display(header: "Attention", message: "This does not appear to be the DEPNotify app.")
                            userDefaults.set("/Applications/Utilities/DEPNotify.app", forKey: "DEPNotifyPath")
                        } else {
                            userDefaults.set("\(String(describing: self.DEPNotifyPath))", forKey: "DEPNotifyPath")
                        
                            generateScript_Action(self)
                        }
                        userDefaults.synchronize()
                    }
                } // openPanel.begin - end
                // if importFiles_button.state - end
            }
        } else {
            print("found DEPNotify")
            generateScript_Action(self)
        }
    }
    
        
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.tag {
            case 0:
                userDefaults.set(jamfServer_TextField.stringValue, forKey: "jamfServer")
            case 1:
                userDefaults.set(jamfUser_TextField.stringValue, forKey: "jamfUser")
            case 100:
                print("edited setting")
            default:
                break
            }
        }
    }
    
    @IBAction func endValueEdit_Action(_ sender: Any) {

        var rectArray = [String]()
        let rav = settings_TableView.visibleRect

        var recttemp = "\(rav)".dropFirst()
        recttemp = "\(recttemp)".dropLast()
        rectArray = "\(recttemp)".components(separatedBy: ", ")
        rectArray[1] = "\(Float(rectArray[1])! + 25)"
        let scrollPos = NSRectFromString("{{\(rectArray[0]), \(rectArray[1])}, {\(rectArray[2]), \(rectArray[3])}}")

        let currentlySelectedRow = settings_TableView.selectedRow
        if currentlySelectedRow >= 0 {
            let rawKeyName = friendlyToRawName(friendlyName: settingsArray[settings_TableView.selectedRow].keyName)
    //        print("rawKeyNameArray: \(rawKeyNameArray)")
            if rawKeyName != "" {
//                print("[endValueEdit_Action] userDefaults.set(\(settingsArray[settings_TableView.selectedRow].keyValue), forKey: \(settingsArray[settings_TableView.selectedRow].keyName))")
//                print("all keys: \((keys.namesDictionary as NSDictionary).allKeys(for: settingsArray[settings_TableView.selectedRow].keyName))")
    //            print("all keys: \(rawKeyName)")
                if validInput(key: rawKeyName, value: "\(settingsArray[currentlySelectedRow].keyValue)") {
                    userDefaults.set("\(settingsArray[currentlySelectedRow].keyValue)", forKey: "\(rawKeyName)")
                    userDefaults.synchronize()

//                    print("[endValueEdit_Action] userDefaults.set(\(settingsArray[settings_TableView.selectedRow].keyValue), forKey: \(rawKeyName))")

                    if rawKeyName == "ORG_NAME" {
                        userDefaults.synchronize()
                        refreshKeysTable()
                        settings_TableView.selectRowIndexes(.init(integer: currentlySelectedRow), byExtendingSelection: false)
                        settings_TableView.scrollToVisible(scrollPos)
                    }

                } else {
                    refreshKeysTable()
                    settings_TableView.selectRowIndexes(.init(integer: currentlySelectedRow), byExtendingSelection: false)
                    settings_TableView.scrollToVisible(scrollPos)
                }
            } else {
                print("Command Failed: userDefaults.set(\(settingsArray[settings_TableView.selectedRow].keyValue), forKey: \(settingsArray[settings_TableView.selectedRow].keyName))")
            }
            userDefaults.synchronize()
        }
    }
    

    @objc func tableViewDoubleClick(_ sender:AnyObject) {
      
        guard settings_TableView.selectedRow >= 0 else {
            return
        }
        
        settings_TableView.editColumn(1, row: settings_TableView.selectedRow, with: nil, select: true)
    }
    
    func validInput(key: String, value: String) -> Bool {
        var inputIsValid = true
//        print("[validInput] key: \(key)     value: \(String(describing: keys.settingsDict["\(key)"]!))")
        switch key {
        case "TESTING_MODE","FULLSCREEN","COMPLETE_METHOD_DROPDOWN_ALERT","NO_SLEEP","SELF_SERVICE_CUSTOM_BRANDING","EULA_ENABLED","REGISTRATION_ENABLED","REG_TEXT_LABEL_1_OPTIONAL","REG_TEXT_LABEL_2_OPTIONAL":
            if value.lowercased() != "true"  && value.lowercased() != "false" {
                Alert().display(header: "Attention:", message: "Value must be set to either true or false.")
                inputIsValid = false
            }
        case "STATUS_TEXT_ALIGN":
            if value.lowercased() != "left" && value.lowercased() != "center" && value.lowercased() != "right" {
                Alert().display(header: "Attention:", message: "Value must be set to either left, center, or right.")
                inputIsValid = false
            }
        default:
            break
        }
        return inputIsValid
    }
    
    func friendlyToRawName(friendlyName: String) -> String {
        var rawName = ""
        let rawKeyNameArray = (keys.namesDictionary as NSDictionary).allKeys(for: friendlyName)
        if rawKeyNameArray.count == 1 {
            rawName = "\(rawKeyNameArray[0])"
        }
        return rawName
    }
    
    // function to return exit code of bash command - start
    func myExitCode(cmd: String, args: String...) -> Int8 {
        //var pipe_pkg = Pipe()
        let task_pkg = Process()
        
        task_pkg.launchPath = cmd
        task_pkg.arguments = args
        //task_pkg.standardOutput = pipe_pkg
        //var test = task_pkg.standardOutput
        
        task_pkg.launch()
        task_pkg.waitUntilExit()
        let result = task_pkg.terminationStatus
        
        return(Int8(result))
    }
    // function to return exit code of bash command - end
    
    func refreshKeysTable() {
        var firstKey = true
        let sortedNameArray = keys.nameArray.sorted()
        
        // Testing Mode
        keys.settingsDict["TESTING_MODE"] = userDefaults.string(forKey: "TESTING_MODE") ?? "true"
        
        // General Appearance - start
        keys.settingsDict["FULLSCREEN"] = userDefaults.string(forKey: "FULLSCREEN") ?? "false"
        keys.settingsDict["BANNER_IMAGE_PATH"] = userDefaults.string(forKey: "BANNER_IMAGE_PATH") ?? "/Applications/Self Service.app/Contents/Resources/AppIcon.icns"
        keys.settingsDict["ORG_NAME"] = userDefaults.string(forKey: "ORG_NAME") ?? "Organization"
        keys.settingsDict["BANNER_TITLE"] = userDefaults.string(forKey: "BANNER_TITLE") ?? "Welcome to \(String(describing: keys.settingsDict["ORG_NAME"]!))"
        keys.settingsDict["SUPPORT_CONTACT_DETAILS"] = userDefaults.string(forKey: "SUPPORT_CONTACT_DETAILS") ?? "email support@organization.com"
        keys.settingsDict["MAIN_TEXT"] = userDefaults.string(forKey: "MAIN_TEXT") ?? "Thanks for choosing a Mac at \(String(describing: keys.settingsDict["ORG_NAME"]!))! We want you to have a few applications and settings configured before you get started with your new Mac. This process should take 10 to 20 minutes to complete. \n \n If you need additional software or help, please visit the Self Service app in your Applications folder or on your Dock."
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
        keys.settingsDict["HELP_BUBBLE_BODY"] = userDefaults.string(forKey: "HELP_BUBBLE_BODY") ?? "This tool at \(String(describing: keys.settingsDict["ORG_NAME"]!)) is designed to help with new employee onboarding. If you have issues, please \(String(describing: keys.settingsDict["SUPPORT_CONTACT_DETAILS"]!))"
        
        // Error Screen Text - start
        keys.settingsDict["ERROR_BANNER_TITLE"] = userDefaults.string(forKey: "ERROR_BANNER_TITLE") ?? "Uh oh, Something Needs Fixing!"
        keys.settingsDict["ERROR_MAIN_TEXT"] = userDefaults.string(forKey: "ERROR_MAIN_TEXT") ?? "We are sorry that you are experiencing this inconvenience with your new Mac. However, we have the nerds to get you back up and running in no time! \n \n Please contact IT right away and we will take a look at your computer ASAP. \n \n \(String(describing: keys.settingsDict["SUPPORT_CONTACT_DETAILS"]!))"
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
        keys.settingsDict["SELF_SERVICE_CUSTOM_WAIT"] = userDefaults.string(forKey: "SELF_SERVICE_CUSTOM_WAIT") ?? "20"
        
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
        keys.settingsDict["REGISTRATION_TITLE"] = userDefaults.string(forKey: "REGISTRATION_TITLE") ?? "Register Mac at \(String(describing: keys.settingsDict["ORG_NAME"]!))"
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
        keys.settingsDict["REG_POPUP_LABEL_4_HELP_TEXT"] = userDefaults.string(forKey: "REG_POPUP_LABEL_4_HELP_TEXT") ?? "This dropdown is currently not in use. All code is here ready for you to use. It can also be hidden by removing the contents of the REG_POPUP_LABEL_4 variable."
        // Popup 4 - end
        
        
        for keyName in sortedNameArray {
            if let _ = keys.settingsDict[keyName] {
                let value = keys.settingsDict[keyName]
                if !firstKey {
                    settingsArray.append(Setting(keyName: keys.namesDictionary[keyName]!, keyValue: value!))
                } else {
//                    settingsArray = [Setting(keyName: keyName, keyValue: value!)]
                    settingsArray = [Setting(keyName: keys.namesDictionary[keyName]!, keyValue: value!)]
                    firstKey = false
                }
            }
        }
    }
    
    func savePasswordSetting() {
        switch savePassword_Button.state.rawValue {
        case 1:
            userDefaults.set(1, forKey: "savePassword")
        default:
            // don't save/remove password
            userDefaults.set(0, forKey: "savePassword")
            let regexKey = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
            let credKey = regexKey.stringByReplacingMatches(in: self.jamfServer_TextField.stringValue, options: [], range: NSRange(0..<self.jamfServer_TextField.stringValue.utf16.count), withTemplate: "")
            let result = Credentials2().remove(service: "DEPNotifyHelper - "+credKey)
            print("result of password removal: \(result)")
        }
        userDefaults.synchronize()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // watch for changes between light and dark mode
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged(sender:)), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
        
        jamfServer_TextField.stringValue  = userDefaults.string(forKey: "jamfServer") ?? "https://<server>.jamfcloud.com"
        jamfUser_TextField.stringValue    = userDefaults.string(forKey: "jamfUser") ?? ""
        if (jamfServer_TextField.stringValue != "") && (jamfUser_TextField.stringValue != "") {
            let regexKey        = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
            let credKey         = regexKey.stringByReplacingMatches(in: jamfServer_TextField.stringValue, options: [], range: NSRange(0..<jamfServer_TextField.stringValue.utf16.count), withTemplate: "")
            let credentailArray  = Credentials2().retrieve(service: "DEPNotifyHelper - "+credKey)
            if credentailArray.count == 2 {
                jamfUserPwd_TextField.stringValue = credentailArray[1]
            }
        }
        let savePasswordSetting = userDefaults.integer(forKey: "savePassword")
        savePassword_Button.state = NSControl.StateValue(rawValue: savePasswordSetting)
        
        // configure TextField so that we can monitor when editing is done
        self.jamfServer_TextField.delegate = self
        self.jamfUser_TextField.delegate   = self
        
        // Do any additional setup after loading the view.
        settings_TableView.target       = self
        settings_TableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        policies_TableView.delegate   = self
        policies_TableView.dataSource = self
        
        refreshKeysTable()
        
        // bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
        
    }

    override func viewDidAppear() {
        DispatchQueue.main.async {
            if self.isDarkMode {
                print("darkmode")
                self.view.layer?.backgroundColor = CGColor(red: 0x24/255.0, green: 0x24/255.0, blue: 0x24/255.0, alpha: 1.0)
            } else {
                print("lightmode")
                self.view.layer?.backgroundColor = CGColor(red: 0xE9/255.0, green: 0xE9/255.0, blue: 0xE9/255.0, alpha: 1.0)
            }
        }
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
    
        // Help Window
        @IBAction func showHelpWindow(_ sender: AnyObject) {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let helpWindowController = storyboard.instantiateController(withIdentifier: "Help View Controller") as! NSWindowController
//            if !windowIsVisible(windowName: "Help") {
                helpWindowController.window?.hidesOnDeactivate = false
                helpWindowController.showWindow(self)
//            }
            
    //        if let helpWindow = helpWindowController.window {
    ////            let helpViewController = helpWindow.contentViewController as! HelpViewController
    //
    //            let application = NSApplication.shared
    //            application.runModal(for: helpWindow)
    //
    //            helpWindow.close()
    //        }
        }
}
extension String {
    var fqdnFromUrl: String {
        get {
            var fqdn = ""
            let nameArray = self.components(separatedBy: "://")
            if nameArray.count > 1 {
                fqdn = nameArray[1]
            } else {
                fqdn =  self
            }
            if fqdn.contains(":") {
                let fqdnArray = fqdn.components(separatedBy: ":")
                fqdn = fqdnArray[0]
            }
            return fqdn
        }
    }
    var pathToString: String {
        get {
            var newPath = ""
            newPath = self.replacingOccurrences(of: "file://", with: "")
            newPath = newPath.replacingOccurrences(of: "%20", with: " ")
            return newPath
        }
    }
}
