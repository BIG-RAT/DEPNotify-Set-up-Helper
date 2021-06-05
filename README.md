# DEPNotify-Set-up-Helper
App to help configure DEPNotify

Download: [DEPNotify Set-up Helper](https://github.com/BIG-RAT/DEPNotify-Set-up-Helper/releases/download/current/DEPNotify.Set-up.Helper.zip)

![DEPNotify Set-up Helper](./DEPNotify%20Set-up%20Helper/help/images/app.png "DEPNotify Set-up Helper")

Configure your DEPNotify-Starter script (https://github.com/jamf/DEPNotify-Starter) with a GUI.

Enter your server URL and credentials then click refresh to get a list of policies to run through DEPNotify.  Select the policies to run.  Use command or shift click to select multiple policies.  Use the table on the left to customize the script.

Use the Preview button to run DEPNotify in testing mode on the machine you're working on.  For best results you may need to run the [depNotifyReset.sh](https://github.com/jamf/DEPNotify-Starter/blob/master/depNotifyReset.sh) script.  Note, DEPNotify.app needs to be on the machine.

Be aware updating Organization Name will automatically reset the following to use the updated name:

*  Banner Title
*  Help Bubble Body
*  Main Text
*  Registration Title

Updating Support Contact Details updates the following:

* Help Bubble Body
* Error Main Text

<br/>

**History:**

2021-06-05: Added ability to preview (test) the script directly from the app.  Fixed issued where prompt for Department would appear when not wanted.  Better handling of app display between light and dark modes.

2021-02-06: Updated to coincide with the [DEPNotify-Starter](https://github.com/jamf/DEPNotify-Starter) script.

2020-10-05: Fixed issue where nothing was being written to DEPNotify.sh for Popup 3 and Popup 4.

2020-03-24: Initial commit.