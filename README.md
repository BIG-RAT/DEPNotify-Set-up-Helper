# DEPNotify-Set-up-Helper
App to help configure DEPNotify

Download: [DEPNotify Set-up Helper](https://github.com/BIG-RAT/DEPNotify-Set-up-Helper/releases/download/current/DEPNotify.Set-up.Helper.zip)

![DEPNotify Set-up Helper](./DEPNotify%20Set-up%20Helper/help/images/app.png "DEPNotify Set-up Helper")

Configure your DEPNotify-Starter script (https://github.com/jamf/DEPNotify-Starter) with a GUI.

Enter your server URL and credentials then click refresh to get a list of policies to run through DEPNotify.  Select the policies to run.  Use command or shift click to select multiple policies.  Use the table on the left to customize the script.

Be aware updating Organization Name will automatically reset the following to use the updated name:

*  Banner Title
*  Help Bubble Body
* 	Main Text
* 	Registration Title

Updating Support Contact Details updates the following:

* Help Bubble Body
* Error Main Text

<br/>

**History:**

2021-02-06: Updated to coincide with the [DEPNotify-Starter](https://github.com/jamf/DEPNotify-Starter) script.

2020-10-05: Fixed issue where nothing was being written to DEPNotify.sh for Popup 3 and Popup 4.  Thanks @Christopher Stout for the heads up.

2020-03-24: Initial commit.