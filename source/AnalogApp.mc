//
// Copyright 2016-2017 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

using Toybox.Application;
using Toybox.WatchUi;

var settingsChanged=true;

var _bluetoothStatus = false;
var _doNotDisturbOn = false;
var _twelvehourtime = true;
var _batteryColourLevelOn = true;
var _moveBarOn = false;
var _lowPowerSeconds = false;
var _touchOn = true;
var _casioDataField = 2;
var _casioDataFieldLeft = 0;
var _fontSizeAdjust = 0;
var fontSizeAdjustNames = ["Smaller","Default","Larger"];

var _kmmiles = 0;
var kmmilesNames = ["km","miles"];

var _metersfeet = 0;
var metersfeetNames = ["meters","feet"];

var _pressure = 0;
var pressureNames = ["hPa","millibar","mmHg","inHg"];

var _celsiusfahrenheit = 0;
var celsiusfahrenheitNames = ["Celsius","Fahrenheit"];

var _timeZoneDigitalOn = false;
var _daylightSavingOn = false;
var _timeZone = 15;

var timeZoneNames = [
  "(UTC-12) Intl Date Line",
  "(UTC-11) Midway, Samoa",
  "(UTC-10) Hawaii",
  "(UTC-9) Alaska",
  "(UTC-8) Pacific Time",
  "(UTC-7) Mountain Time",
  "(UTC-6) Central America",
  "(UTC-6) Central Time",
  "(UTC-5) Eastern Time",
  "(UTC-4) Atlantic Time",
  "(UTC-3:30) Newfoundland",
  "(UTC-3) Brasilia",
  "(UTC-2) Mid-Atlantic",
  "(UTC-1) Azores",
  "(UTC+0) Casablanca",
  "(UTC+0) London",
  "(UTC+1) Amsterdam, Berlin",
  "(UTC+1) Belgrade, Prague",
  "(UTC+1) Brussels, Paris",
  "(UTC+1) Sarajevo, Warsaw",
  "(UTC+1) West Africa",
  "(UTC+2) Athens, Istanbul",
  "(UTC+2) Beirut, Cairo",
  "(UTC+2) Helsinki, Kyiv",
  "(UTC+2) Jerusalem",
  "(UTC+3) Kuwait, Riyadh",
  "(UTC+3) Moscow",
  "(UTC+3) Nairobi",
  "(UTC+3:30) Tehran",
  "(UTC+4) Abu Dhabi",
  "(UTC+4) Baku",
  "(UTC+4:30) Kabul",
  "(UTC+5) Yekaterinburg",
  "(UTC+5) Islamabad",
  "(UTC+5:30) Sri Lanka",
  "(UTC+5:30) Mumbai, Delhi",
  "(UTC+5:45) Kathmandu",
  "(UTC+6) Almaty",
  "(UTC+6) Astana, Dhaka",
  "(UTC+6:30) Yangon",
  "(UTC+7) Bangkok, Jakarta",
  "(UTC+7) Krasnoyarsk",
  "(UTC+8) Beijing, HK",
  "(UTC+8) Kuala Lumpur",
  "(UTC+8) Irkutsk",
  "(UTC+8) Perth",
  "(UTC+9) Tokyo",
  "(UTC+9) Seoul",
  "(UTC+9:30) Adelaide",
  "(UTC+9:30) Darwin",
  "(UTC+10) Brisbane, Sydney",
  "(UTC+10) Guam",
  "(UTC+10) Vladivostok",
  "(UTC+11) Magadan",
  "(UTC+12) Auckland",
  "(UTC+12) Fiji",
  "(UTC+13) Nuku'alofa"
];

// casioDataField property values (non-sequential) and their display names
var casioDataFieldValues = [0, 1, 2, 23, 3, 4, 5, 6, 7, 26, 27, 8, 9, 10, 11, 12, 13, 21, 14, 15, 22, 16, 17, 18, 19, 20, 25, 24];
var casioDataFieldNames = ["OFF", "2nd Time", "Battery", "Body Battery", "Distance (day)", "Distance (week)",
"Calories", "Steps", "Floors", "Active min (day)", "Active min (week)",
"Heart Rate", "Notifications", "Alarms", "Next Sun Event", "Sunrise", "Sunset",
"Sunrise+Sunset", "Latitude", "Longitude", "Lat+Long", "Altitude",
"Sea Lvl Pressure", "Ambient Pressure", "Pressure History", "Temperature", "Outside Temp", "Recovery"];



// This is the primary entry point of the application.
class AnalogWatch extends Application.AppBase
{

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    		settingsChanged = true;
    }

    function onStop(state) {
    }
    
    // This method runs each time the main application starts.
    function getInitialView() {
    	
    	// This is essential as it forces on start to read and set all the global watch settings
    	settingsChanged = true;
        
        if( Toybox.WatchUi has :WatchFaceDelegate ) {
            return [new AnalogView(), new AnalogDelegate()];
        } else {
            return [new AnalogView()];
        }
    }

    function onSettingsChanged() {
    		settingsChanged = true;
    		WatchUi.requestUpdate();
    }

    function getSettingsView() {
        return [new MainMenu(),new MainMenuDelegate()];
    }

class MainMenu extends WatchUi.Menu2 {
    function initialize() 
    {
        Menu2.initialize(null);
        Menu2.setTitle("Settings");

        // Load current values for display
        try { _twelvehourtime = Application.Properties.getValue("twelvehourtime"); } catch (e) { _twelvehourtime = true; }
        try { _casioDataField = Application.Properties.getValue("casioDataField"); if (_casioDataField == null) { _casioDataField = 2; } } catch (e) { _casioDataField = 2; }
        try { _casioDataFieldLeft = Application.Properties.getValue("casioDataFieldLeft"); if (_casioDataFieldLeft == null) { _casioDataFieldLeft = 0; } } catch (e) { _casioDataFieldLeft = 0; }
        try { _bluetoothStatus = Application.Properties.getValue("bluetoothStatus"); } catch (e) { _bluetoothStatus = false; }
        try { _doNotDisturbOn = Application.Properties.getValue("doNotDisturbOn"); } catch (e) { _doNotDisturbOn = false; }
        try { _batteryColourLevelOn = Application.Properties.getValue("batteryColourLevelOn"); } catch (e) { _batteryColourLevelOn = true; }
        try { _moveBarOn = Application.Properties.getValue("moveBarOn"); } catch (e) { _moveBarOn = false; }
        try { _lowPowerSeconds = Application.Properties.getValue("lowPowerSeconds"); } catch (e) { _lowPowerSeconds = false; }
        try { _touchOn = Application.Properties.getValue("touchOn"); } catch (e) { _touchOn = false; }
        try { _fontSizeAdjust = Application.Properties.getValue("fontSizeAdjust"); if (_fontSizeAdjust == null) { _fontSizeAdjust = 0; } } catch (e) { _fontSizeAdjust = 0; }
        try { _kmmiles = Application.Properties.getValue("kmmiles"); } catch (e) { _kmmiles = 0; }
        try { _metersfeet = Application.Properties.getValue("metersfeet"); } catch (e) { _metersfeet = 0; }
        try { _pressure = Application.Properties.getValue("pressure"); } catch (e) { _pressure = 0; }
        try { _celsiusfahrenheit = Application.Properties.getValue("celsiusfahrenheit"); } catch (e) { _celsiusfahrenheit = 0; }
        try { _timeZoneDigitalOn = Application.Properties.getValue("timeZoneOn"); } catch (e) { _timeZoneDigitalOn = false; }
        try { _daylightSavingOn = Application.Properties.getValue("daylightSaving"); } catch (e) { _daylightSavingOn = false; }
        try { _timeZone = Application.Properties.getValue("timeZone"); if (_timeZone == null) { _timeZone = 15; } } catch (e) { _timeZone = 15; }

        // Find current data field names for display
        var dfName = "Battery";
        for (var i = 0; i < casioDataFieldValues.size(); i++) {
            if (casioDataFieldValues[i] == _casioDataField) { dfName = casioDataFieldNames[i]; break; }
        }
        var dfNameLeft = "OFF";
        for (var i = 0; i < casioDataFieldValues.size(); i++) {
            if (casioDataFieldValues[i] == _casioDataFieldLeft) { dfNameLeft = casioDataFieldNames[i]; break; }
        }

        Menu2.addItem(new WatchUi.ToggleMenuItem("12 HOUR TIME", null, "twelvehourtime", _twelvehourtime, null));
        Menu2.addItem(new WatchUi.MenuItem("CLOCK FONT SIZE", fontSizeAdjustNames[_fontSizeAdjust + 1], "fontSizeAdjust", {}));
        Menu2.addItem(new WatchUi.MenuItem("DATA RIGHT", dfName, "casioDataField", {}));
        Menu2.addItem(new WatchUi.MenuItem("DATA LEFT", dfNameLeft, "casioDataFieldLeft", {}));
        Menu2.addItem(new WatchUi.MenuItem("UNITS", null, "units", {}));
        Menu2.addItem(new WatchUi.MenuItem("SPECIAL FEATURES", null, "specialFeatures", {}));
        Menu2.addItem(new WatchUi.MenuItem("TIME ZONE", null, "timeZoneSettings", {}));
        Menu2.addItem(new WatchUi.MenuItem("VERSION", Application.Properties.getValue("appVersion"), "nothing", {}));
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

  	function onSelect(item) 
    {
  		var id = item.getId();
		
        if (id.equals("twelvehourtime")) {
            _twelvehourtime = !_twelvehourtime;
            Application.Properties.setValue("twelvehourtime", _twelvehourtime);
        }
        else if (id.equals("fontSizeAdjust")) {
            _fontSizeAdjust = _fontSizeAdjust + 1;
            if (_fontSizeAdjust > 1) { _fontSizeAdjust = -1; }
            item.setSubLabel(fontSizeAdjustNames[_fontSizeAdjust + 1]);
            Application.Properties.setValue("fontSizeAdjust", _fontSizeAdjust);
        }
        else if (id.equals("casioDataField")) {
            var idx = 0;
            for (var i = 0; i < casioDataFieldValues.size(); i++) {
                if (casioDataFieldValues[i] == _casioDataField) { idx = i; break; }
            }
            idx = (idx + 1) % casioDataFieldValues.size();
            _casioDataField = casioDataFieldValues[idx];
            item.setSubLabel(casioDataFieldNames[idx]);
            Application.Properties.setValue("casioDataField", _casioDataField);
        }
        else if (id.equals("casioDataFieldLeft")) {
            var idx = 0;
            for (var i = 0; i < casioDataFieldValues.size(); i++) {
                if (casioDataFieldValues[i] == _casioDataFieldLeft) { idx = i; break; }
            }
            idx = (idx + 1) % casioDataFieldValues.size();
            _casioDataFieldLeft = casioDataFieldValues[idx];
            item.setSubLabel(casioDataFieldNames[idx]);
            Application.Properties.setValue("casioDataFieldLeft", _casioDataFieldLeft);
        }
        else if (id.equals("units")) {
            var subMenu = new WatchUi.Menu2({:title => "UNITS"});
            subMenu.addItem(new WatchUi.MenuItem("Distance (km/mi)", kmmilesNames[_kmmiles], "kmmiles", {}));
            subMenu.addItem(new WatchUi.MenuItem("Distance (m/ft)", metersfeetNames[_metersfeet], "metersfeet", {}));
            subMenu.addItem(new WatchUi.MenuItem("Pressure", pressureNames[_pressure], "pressure", {}));
            subMenu.addItem(new WatchUi.MenuItem("Temperature (C/F)", celsiusfahrenheitNames[_celsiusfahrenheit], "celsiusfahrenheit", {}));
            WatchUi.pushView(subMenu, new SubMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
        else if (id.equals("specialFeatures")) {
            var subMenu = new WatchUi.Menu2({:title => "SPECIAL FEATURES"});
            subMenu.addItem(new WatchUi.ToggleMenuItem("Touch screen calculator (bottom) and stopwatch (right)", null, "touchOn", _touchOn, null));
            subMenu.addItem(new WatchUi.ToggleMenuItem("Battery Colour", null, "batteryColourLevelOn", _batteryColourLevelOn, null));
            subMenu.addItem(new WatchUi.ToggleMenuItem("Move Bar", null, "moveBarOn", _moveBarOn, null));
            subMenu.addItem(new WatchUi.ToggleMenuItem("Do Not Disturb", null, "doNotDisturbOn", _doNotDisturbOn, null));
            subMenu.addItem(new WatchUi.ToggleMenuItem("Bluetooth Status", null, "bluetoothStatus", _bluetoothStatus, null));
            subMenu.addItem(new WatchUi.ToggleMenuItem("Low Power Seconds", null, "lowPowerSeconds", _lowPowerSeconds, null));          
            WatchUi.pushView(subMenu, new SubMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
        else if (id.equals("timeZoneSettings")) {
            var subMenu = new WatchUi.Menu2({:title => "TIME ZONE"});
            subMenu.addItem(new WatchUi.ToggleMenuItem("Second Time Zone", null, "timeZoneOn", _timeZoneDigitalOn, null));
            subMenu.addItem(new WatchUi.ToggleMenuItem("Daylight Saving", null, "daylightSaving", _daylightSavingOn, null));
            subMenu.addItem(new WatchUi.MenuItem("Time Zone", timeZoneNames[_timeZone], "timeZone", {}));
            WatchUi.pushView(subMenu, new SubMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
  	
  	function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        settingsChanged = true;
        WatchUi.requestUpdate();
    }
    
}


}

class SubMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(subMenuItem) {
        var id = subMenuItem.getId();

        if (id.equals("kmmiles")) {
            _kmmiles = (_kmmiles + 1) % kmmilesNames.size();
            subMenuItem.setSubLabel(kmmilesNames[_kmmiles]);
            Application.Properties.setValue("kmmiles", _kmmiles);
        }
        else if (id.equals("metersfeet")) {
            _metersfeet = (_metersfeet + 1) % metersfeetNames.size();
            subMenuItem.setSubLabel(metersfeetNames[_metersfeet]);
            Application.Properties.setValue("metersfeet", _metersfeet);
        }
        else if (id.equals("pressure")) {
            _pressure = (_pressure + 1) % pressureNames.size();
            subMenuItem.setSubLabel(pressureNames[_pressure]);
            Application.Properties.setValue("pressure", _pressure);
        }
        else if (id.equals("celsiusfahrenheit")) {
            _celsiusfahrenheit = (_celsiusfahrenheit + 1) % celsiusfahrenheitNames.size();
            subMenuItem.setSubLabel(celsiusfahrenheitNames[_celsiusfahrenheit]);
            Application.Properties.setValue("celsiusfahrenheit", _celsiusfahrenheit);
        }
        else if (id.equals("timeZoneOn")) {
            _timeZoneDigitalOn = !_timeZoneDigitalOn;
            Application.Properties.setValue("timeZoneOn", _timeZoneDigitalOn);
        }
        else if (id.equals("daylightSaving")) {
            _daylightSavingOn = !_daylightSavingOn;
            Application.Properties.setValue("daylightSaving", _daylightSavingOn);
        }
        else if (id.equals("timeZone")) {
            _timeZone = (_timeZone + 1) % timeZoneNames.size();
            subMenuItem.setSubLabel(timeZoneNames[_timeZone]);
            Application.Properties.setValue("timeZone", _timeZone);
        }
        else if (id.equals("batteryColourLevelOn")) {
            _batteryColourLevelOn = !_batteryColourLevelOn;
            Application.Properties.setValue("batteryColourLevelOn", _batteryColourLevelOn);
        }
        else if (id.equals("moveBarOn")) {
            _moveBarOn = !_moveBarOn;
            Application.Properties.setValue("moveBarOn", _moveBarOn);
        }
        else if (id.equals("doNotDisturbOn")) {
            _doNotDisturbOn = !_doNotDisturbOn;
            Application.Properties.setValue("doNotDisturbOn", _doNotDisturbOn);
        }
        else if (id.equals("bluetoothStatus")) {
            _bluetoothStatus = !_bluetoothStatus;
            Application.Properties.setValue("bluetoothStatus", _bluetoothStatus);
        }
        else if (id.equals("lowPowerSeconds")) {
            _lowPowerSeconds = !_lowPowerSeconds;
            Application.Properties.setValue("lowPowerSeconds", _lowPowerSeconds);
        }
        else if (id.equals("touchOn")) {
            _touchOn = !_touchOn;
            Application.Properties.setValue("touchOn", _touchOn);
        }
	}

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        settingsChanged = true;
        WatchUi.requestUpdate();
    }
}
