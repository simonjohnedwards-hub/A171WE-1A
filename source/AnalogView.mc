// Copyright 2018 by Simon Edwards
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
// Written by Simon Edwards - 2018
// ===== CASIO A171WE-1A STYLE WATCH FACE DRAWING =====

// 1.4.4
//  -  Improvement to position of symbols
// 1.4.3 
//   - Change clock font size 
// 1.4.2 
//  - Improved calculator to visually show when an operator has been pressed
// 1.4.1 
//  - Menu names and location updated
// 1.4.0
//  - Added as stop watch with right press
// 1.3.2 - Not released
//	- Changed App name to A171WE-1A
//  - Moved the topText down slightly so movebar doesn't overlap it on round watches
// 1.3.1 - 14 March 2026
//   - Round calculator design: buttons fit within circular watch face using chord-based layout
//   - Added % button next to equals for percentage calculations
//   - Scientific notation for large/small calculator results
//   - Fixed inner bezel arcs overshooting top lines (Math.round instead of Math.ceil)
//   - Line endpoints derived from arc angles for seamless bezel shape
//   - SDK 9.1.0
// 1.3.0 - 13 March 2026
//   - Added touchscreen calculator overlay (tap bottom of watch face to open)
//   - Touchscreen enabled by default, configurable in SPECIAL FEATURES menu
//   - Added configurable top text setting (default "NOMIS")
//   - Moved Battery Colour, Move Bar, DND, Bluetooth Status, Low Power Seconds, Touchscreen into SPECIAL FEATURES sub-menu
// 1.2.0 - Improved on-watch menus
// 1.1.1 - removed notification count from bottom right to save memory and because it was not fitting well in the space with the new left data field 17 March 2026
// 1.1.0 - 13 March 2026
//   - SDK 9.1.0
//   - Added left data field with all same options as right data field
//   - Added configurable setting "casioDataFieldLeft" for left data field
//   - Left data field supports symbols, battery colour coding, and heart rate partial updates
//   - Fixed inner bezel arcs not meeting top/bottom lines (Math.ceil on arc angles)
//   - Added width-fitting for digital time + seconds (steps font down if too wide for LCD)
//   - Seconds now drawn exclusively by onPartialUpdate to avoid double-drawing
//   - Seconds hidden in low power mode by default
//   - Added "lowPowerSeconds" setting to optionally show seconds in low power mode
//   - Low power colours applied in onPartialUpdate for correct rendering when asleep
//   - Replaced per-frame symbolFields array with hasSymbolField() function to reduce memory
//   - Added left data field and low power seconds to on-watch settings menu
// 1.0.1 - tweak of WATER RESIST text position and bezel bottom line position 12 March 2026
// 1.0.0 - Initial version released to public 12 March 2026

using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.Application;
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.SensorHistory;
using Toybox.Weather;
using Toybox.UserProfile;

var appVersion = "1.4.4"; 

var partialUpdatesAllowed = false;

// Calculator overlay state (global so AnalogDelegate and AnalogView can share)
var calculatorActive = false;
var calcDisplayText = "0";
var calcCurrentValue = 0.0;
var calcPendingOp = null;
var calcNewInput = true;
var calcHasDecimal = false;

// Stopwatch overlay state
var stopwatchActive = false;
var stopwatchRunning = false;
var stopwatchStartTime = 0;
var stopwatchElapsed = 0;
var stopwatchLap = 0;
var stopwatchLapText = "";

// This implements the watch face
class AnalogView extends WatchUi.WatchFace
{
	// BEGIN GLOBAL VARIABLES
    var isAwake = true;

	var offscreenBuffer;
    var screenCenterPoint;
    var fullScreenRefresh;

    var heartRate = "--";
    var lastCurrentHeartRate = 0;

	var timeString;
		
	// Battery variables
	var batteryLevel = 50;
  	var bodyBattery = null; // Body Battery - 0-24 Drained RED, 25-49 Very Low ORANGE, 50-74 Low YELLOW, 75-100 Good GREEN  

	// Time variables
    var timeZoneOn = false;
	var timeZoneOffset = 0;
	var twelveHourTimeOn = true;
	var casioDataField = 2;
	var casioDataFieldLeft = 0;
	var topText = "NOMIS";
	var touchOn = false;
	var lowPowerSeconds = false;
	var fontSizeAdjust = 0;
    var sunrise = 6.0; //this the sunrise in hours including fraction
    var sunriseTomorrow = 6.0;
    var sunset = 18.0; //this the sunrise in hours including fraction
    var sunsetOn = false;
    var today = 0;
    var todayZone = 0;
    var latitude = 52.0;
	var longitude = 0.14;

    var bluetoothStatusOn = true;

	var altitudeString = "-.-";
	var	pressureString = "-.-";
	var	pressureHistoryString = "-.-";
	
	var kmmiles=true; // true=kms  fales=miles
	var metersfeet=true; // true=meters fales=feet
	var arrayPressureConvert = 1.0;
    var arrayPressureString;
	
	var temperatureString = "-.-";
	var celsiusfahrenheit = true;	
	var bodyBatteryString = "-";

	// Do Not Disturb variables
	var doNotDisturbOn = false;
	var dndSupported = false;
	var doNotDisturbStatus = false;

	var wakeTime = true;

	// Cached device settings - fetched once per frame in onUpdate() to avoid multiple getDeviceSettings() calls
	var notificationCount = 0;
	var alarmCount = 0;
	var phoneConnected = false;

	// Cached clock time - fetched once per frame in onUpdate()
	var cachedClockTime = null;

	// Cached ActivityMonitor.getInfo() - updated once per minute in needSensorUpdate block
	var cachedActivityMonitorInfo = null;

	// Sensor history cached values - updated once per minute to reduce memory pressure
	var lastSensorUpdateMinute = -1;
	var cachedAltitude = null;
	var cachedMeanSeaLevelPressure = null;
	var cachedAmbientPressure = null;
	var pressureNext = null;
	var pressureLast = null;
	var cachedTemperature = null;
	var outsideTemperature = null;
	var cached7DayDistance = 0.0;
	var cachedHeartRate = null;

    // END GLOBAL VARIABLES

    function initialize() {
    // Initialize variables for this view
    	settingsChanged = true;
        WatchFace.initialize();
 		var mySettings = System.getDeviceSettings();

		Application.Properties.setValue("appVersion", appVersion);

        fullScreenRefresh = true;
        partialUpdatesAllowed = ( Toybox.WatchUi.WatchFace has :onPartialUpdate ); // find out if partial updates are availble

        dndSupported = (mySettings has :doNotDisturb);
		//partialUpdatesAllowed = true; // force partial updates to be on for now

        // If Storage is supported check to see if there are lat/lon values available
        // If not write a starting set to Storage
        if ( Toybox.Application has :Storage )
        {
	        if (Application.Storage.getValue("latitude")!=null)
	        {
		       	latitude = Application.Storage.getValue("latitude");
				longitude = Application.Storage.getValue("longitude");
	        } else {
		        Application.Storage.setValue("latitude", latitude);
				Application.Storage.setValue("longitude", longitude);
			}
		}
    }

    function onLayout(dc) {
    // Configure the layout of the watchface for this device

//NEW
        if((Toybox.Graphics has :BufferedBitmap)){//&&(System.SCREEN_SHAPE_ROUND == screenShape)) {
            // Allocate a full screen size buffer with a palette of all colors to draw
            // the background image of the watchface.  This is used to facilitate blanking
            // the second hand during partial updates of the display
            try {
            if (Toybox.Graphics has :createBufferedBitmap) {
				offscreenBuffer = null;
				offscreenBuffer = Graphics.createBufferedBitmap({
					:width=>dc.getWidth(),
					:height=>dc.getHeight()
				});

			} else {
				offscreenBuffer = null;
				offscreenBuffer = new Graphics.BufferedBitmap({
					:width=>dc.getWidth(),
					:height=>dc.getHeight()
				});
			}
			} catch (e) {
				offscreenBuffer = null;
			}
     
		} else {
            offscreenBuffer = null;
        }
//ENDNEW

        screenCenterPoint = [dc.getWidth()/2, dc.getHeight()/2];
    }

    function onUpdate(dc) {
    // Handle the update event

        var width;
        var height;
        // Cache clock time once per frame to avoid multiple API calls
        cachedClockTime = System.getClockTime();
        var clockTime = cachedClockTime;
        var targetDc = null;

        // Cache device settings once per frame to avoid 16+ getDeviceSettings() calls
        var deviceSettings = System.getDeviceSettings();
        alarmCount = deviceSettings.alarmCount;
        notificationCount = deviceSettings.notificationCount;
        phoneConnected = deviceSettings.phoneConnected;
        if (dndSupported) { doNotDisturbStatus = deviceSettings.doNotDisturb; }
        deviceSettings = null;

        // get the current time as an hour in float value
 	    var timeFraction = 1.0*clockTime.hour+1.0*clockTime.min/60.0;        
  	    // Routine to see if wakeTime should be set to true or false to save battery life
        // check if the partial updates is even possible, and if the wakeTime setting has been set
        var wakeTimeSetting = true;
        try { var v = Application.Properties.getValue("wakeTime"); if (v != null) { wakeTimeSetting = v; } } catch (e) {}
        if ( (partialUpdatesAllowed) && (UserProfile has :getProfile) && (wakeTimeSetting) )
        {
	        var profile = UserProfile.getProfile();        
	        if (profile != null && (profile.sleepTime != null) && (profile.sleepTime.value() != null) && (profile.wakeTime != null) && (profile.wakeTime.value() != null)) 
	        {
	        	if (profile.wakeTime.value() <= profile.sleepTime.value())
	        	{
	        		wakeTime = ( (timeFraction >= profile.wakeTime.value()/3600.0) && (timeFraction <= profile.sleepTime.value()/3600.0) ) ? true : false ;
	        	}
	        	else
	        	{
	        		wakeTime = ( (timeFraction >= profile.wakeTime.value()/3600.0) || (timeFraction <= profile.sleepTime.value()/3600.0) ) ? true : false ;
	        	}
	        }
	    } else { wakeTime = true; }
        
       	// Calculate an initial Sunrise Sunset as well as latitude and longitude
       	// the variables sunset and sunrise are in frations of hours
		getSunriseSunset();

       	// sunsetOn routine
       	// If the sunset function is enableed then the flag is set
       	// and at sunset black and white are interchanged, then returned 
       	// to their original state at sunrise
        var sunsetOnSetting = false;
        try { var v = Application.Properties.getValue("sunsetOn"); if (v != null) { sunsetOnSetting = v; } } catch (e) {}
        if (sunsetOnSetting==true) {
        // If the sunsetOn option has been selected then see if we need
        // to change the settings for the time of day
        	// get the current time as an hour in float value
	        //var timeFraction = 1.0*clockTime.hour+1.0*clockTime.min/60.0;

	        // Check if the sun has set and yet to rise, and that the sunsetOn is off,
	        // to see if we need to switch on the sunsetOn value
	        if ( ((timeFraction > sunset)||(timeFraction < sunrise))&&(sunsetOn==false) )
	        {
	        	// make sure we trigger an update on settings to re-get the colour settings
	        	settingsChanged = true;
	        	// change sunsetOn to true to show the sun has set and yet to rise
	        	sunsetOn = true;
	        }
	        // if in fact it is daylight time and the sunsetOn is still enabled
	        // then turn it off
	        else if ( ((timeFraction < sunset)&&(timeFraction > sunrise)) && ( sunsetOn==true) )
	        {
	        	// Force the settings to be read to turn back on the right colours
	        	settingsChanged = true;
	        	// Turn off the sunsetOn to indicate to the colour section to reinstate the colours
	        	sunsetOn = false;
	        }
	    // If the "sunsetOn" options is not enabled make sure to set sunsetOn to off/false
        } else { sunsetOn = false;}

        // We always want to refresh the full screen when we get a regular onUpdate call.
        fullScreenRefresh = true;

		// GET ALL THE SETTING INFORMATION THAT THE USER HAS SELECTED
		// This is designed not to be run all the time but 
		if (settingsChanged==true) {

			//set the first run status to false for the next time this function is accessed

/* CASIO SETTINGS — read directly from Properties to bypass preset/licensing gate */
			try { var v = Application.Properties.getValue("twelvehourtime"); twelveHourTimeOn = (v != null) ? v : true; } catch (e) { twelveHourTimeOn = true; }
			try { var v = Application.Properties.getValue("casioDataField"); casioDataField = (v != null) ? v : 2; } catch (e) { casioDataField = 2; }
			try { var v = Application.Properties.getValue("casioDataFieldLeft"); casioDataFieldLeft = (v != null) ? v : 0; } catch (e) { casioDataFieldLeft = 0; }
			try { var v = Application.Properties.getValue("topText"); topText = (v != null && !v.equals("")) ? v : "NOMIS"; } catch (e) { topText = "NOMIS"; }
			try { var v = Application.Properties.getValue("touchOn"); touchOn = (v != null) ? v : false; } catch (e) { touchOn = false; }
			try { var v = Application.Properties.getValue("bluetoothStatus"); bluetoothStatusOn = (v != null) ? v : true; } catch (e) { bluetoothStatusOn = true; }
			try { var v = Application.Properties.getValue("doNotDisturbOn"); doNotDisturbOn = (v != null) ? v : false; } catch (e) { doNotDisturbOn = false; }
			try { var v = Application.Properties.getValue("batteryColourLevelOn"); _batteryColourLevelOn = (v != null) ? v : true; } catch (e) { _batteryColourLevelOn = true; }
			try { var v = Application.Properties.getValue("lowPowerSeconds"); lowPowerSeconds = (v != null) ? v : false; } catch (e) { lowPowerSeconds = false; }
			try { var v = Application.Properties.getValue("fontSizeAdjust"); fontSizeAdjust = (v != null) ? v : 0; } catch (e) { fontSizeAdjust = 0; }

/* UNITS OF MEASURE OPTIONS */
			try { var v = Application.Properties.getValue("kmmiles"); kmmiles = (v == 0 || v == null) ? true : false; } catch (e) { kmmiles = true; }
			try { var v = Application.Properties.getValue("metersfeet"); metersfeet = (v == 0 || v == null) ? true : false; } catch (e) { metersfeet = true; }
			try { var v = Application.Properties.getValue("celsiusfahrenheit"); celsiusfahrenheit = (v == 0 || v == null) ? true : false; } catch (e) { celsiusfahrenheit = true; }
			var pressureIndex = 0;
			try { var v = Application.Properties.getValue("pressure"); if (v != null && v >= 0 && v <= 3) { pressureIndex = v; } } catch (e) {}
			var pressureConversions = [0.01, 0.01, 0.0075006156130264, 0.00029529983071445];
			var pressureStrings = ["hP", "mb", "mH", "iH"];
			arrayPressureConvert = pressureConversions[pressureIndex];
			arrayPressureString = pressureStrings[pressureIndex];

/* SECOND TIME ZONE */
			try { var v = Application.Properties.getValue("timeZoneOn"); timeZoneOn = (v != null) ? v : false; } catch (e) { timeZoneOn = false; }
			var daylightSavingOn = false;
			try { var v = Application.Properties.getValue("daylightSaving"); daylightSavingOn = (v != null) ? v : false; } catch (e) {}
			var timeZoneIndex = 15;
			try { var v = Application.Properties.getValue("timeZone"); if (v != null) { timeZoneIndex = v; } } catch (e) {}
			if (timeZoneIndex < 0) { timeZoneIndex = 0; }
			if (timeZoneIndex > 56) { timeZoneIndex = 56; }
			var arrayTimeZones = [-12,-11,-10,-9,-8,-7,-6,-6,-5,-4,-3.5,-3,-2,-1,0,0,
				1,1,1,1,1,2,2,2,2,3,3,3,3.5,4,4,4.5,5,5,5.5,5.5,5.75,6,6,6.5,7,7,
				8,8,8,8,9,9,9.5,9.5,10,10,10,11,12,12,13];
			timeZoneOffset = arrayTimeZones[timeZoneIndex];
			if (daylightSavingOn) { timeZoneOffset = timeZoneOffset + 1; }

		   // reset the settings changed flag back to false so as to not enter this loop again unless the settings are changd
		   settingsChanged=false;
	    }

		// Sensor data caching - only update once per minute to reduce memory pressure
		var currentMinute = cachedClockTime != null ? cachedClockTime.min : -1;
		var needSensorUpdate = (currentMinute != lastSensorUpdateMinute);

		if (needSensorUpdate) {
			lastSensorUpdateMinute = currentMinute;

			// Cache ActivityMonitor.getInfo() once per minute for distance, calories, etc.
			cachedActivityMonitorInfo = ActivityMonitor.getInfo();

			// Battery level - once per minute
			batteryLevel = (System.getSystemStats().battery + 0.5).toNumber();

			// Body Battery
			if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
				try {
					var bodyBatteryHistory = SensorHistory.getBodyBatteryHistory({:period => 1});
					if (bodyBatteryHistory != null) {
						var bodySample = bodyBatteryHistory.next();
						if (bodySample != null && bodySample.data != null) {
							bodyBattery = bodySample.data;
							bodyBatteryString = bodyBattery.toNumber().toString();
						}
						bodySample = null;
					}
					bodyBatteryHistory = null;
				} catch(ex) {}
			}

			// Pressure History
			if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getPressureHistory)) {
				try {
					var pressureHistory = SensorHistory.getPressureHistory({:period => 900});
					if (pressureHistory != null) {
						var pressureNextSample = pressureHistory.next();
						var pressureLastSample = pressureHistory.next();
						if (pressureNextSample != null && pressureNextSample.data != null) {
							pressureNext = pressureNextSample.data;
						}
						if (pressureLastSample != null && pressureLastSample.data != null) {
							pressureLast = pressureLastSample.data;
						}
						pressureNextSample = null;
						pressureLastSample = null;
					}
					pressureHistory = null;
				} catch(ex) {}
			}

			// Temperature - once per minute
			if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getTemperatureHistory)) {
				try {
					var temperatureHistory = SensorHistory.getTemperatureHistory({:period => 1});
					if (temperatureHistory != null) {
						var tempSample = temperatureHistory.next();
						if (tempSample != null && tempSample.data != null) {
							cachedTemperature = tempSample.data;
						}
						tempSample = null;
					}
					temperatureHistory = null;
				} catch(ex) {}
			}

			// Outside Temperature (Weather API)
			if ((Toybox has :Weather) && (Toybox.Weather has :getCurrentConditions)) {
				try {
					var weather = Weather.getCurrentConditions();
					if (weather != null && weather.temperature != null) {
						outsideTemperature = weather.temperature;
					}
					weather = null;
				} catch(ex) {}
			}

			// Altitude and pressure from ActivityInfo - once per minute
			var activityInfo = Activity.getActivityInfo();
			if (activityInfo != null) {
				cachedAltitude = (activityInfo has :altitude && activityInfo.altitude != null) ? activityInfo.altitude : null;
				cachedMeanSeaLevelPressure = (activityInfo has :meanSeaLevelPressure && activityInfo.meanSeaLevelPressure != null) ? activityInfo.meanSeaLevelPressure : null;
				cachedAmbientPressure = (activityInfo has :ambientPressure && activityInfo.ambientPressure != null) ? activityInfo.ambientPressure : null;
			}
			activityInfo = null;

			// 7-day distance - cache ActivityMonitor.getHistory() once per minute
			try {
				var actHistArray = ActivityMonitor.getHistory();
				var dist7day = 0.0;
				if (actHistArray != null && actHistArray.size() > 0) {
					for (var i = 0; i < (actHistArray.size()-1); i += 1) {
						if (actHistArray[i] != null && actHistArray[i].distance != null) {
							dist7day = dist7day + actHistArray[i].distance/100000.0;
						}
					}
				}
				cached7DayDistance = dist7day;
				actHistArray = null;
			} catch (ex) {}
		}

		// Heart Rate - still fetch every frame as it changes frequently
		var activityInfoHR = Activity.getActivityInfo();
		if ((Toybox.ActivityMonitor has :getHeartRateHistory) && (activityInfoHR != null && activityInfoHR has :currentHeartRate)) {
			try {
				if (activityInfoHR.currentHeartRate != null) {
					cachedHeartRate = activityInfoHR.currentHeartRate;
					lastCurrentHeartRate = cachedHeartRate;
				} else if (lastCurrentHeartRate > 0) {
					cachedHeartRate = lastCurrentHeartRate;
				} else if (needSensorUpdate) {
					var heartRateHistory = ActivityMonitor.getHeartRateHistory(1, true);
					if (heartRateHistory != null) {
						var heartRateSample = heartRateHistory.next();
						if (heartRateSample != null && heartRateSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
							cachedHeartRate = heartRateSample.heartRate;
						}
						heartRateSample = null;
					}
					heartRateHistory = null;
				}
			} catch(ex) {}
		}
		activityInfoHR = null;

    	// If device can do 1hz, make sure to clear the clip in case you exceeded the
    	// power limit but there's still a clip
    	if(partialUpdatesAllowed) {dc.clearClip();}

        if(null != offscreenBuffer) {
            dc.clearClip();
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            if (Toybox.Graphics has :createBufferedBitmap) {
				var tempTargetDc = offscreenBuffer.get();
				targetDc= tempTargetDc.getDc();
			} else {
				targetDc = offscreenBuffer.getDc();
			}
        } else {targetDc = dc;}
		//targetDc = dc;

		// Get the width and height of the watch face
        width = targetDc.getWidth();
        height = targetDc.getHeight();
		
        
        // ===== CASIO A171W STYLE WATCH FACE DRAWING =====
        targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        targetDc.fillRectangle(0, 0, width, height);

        var cx = width / 2;
        var cy = height / 2;

        // Inner bezel — drawn after outside-LCD text positions are known
        // (placeholder — actual drawing deferred below)

        // Font references
        var labelFont = Graphics.FONT_XTINY;
        var secFont = Graphics.FONT_MEDIUM;
        // Apply font size adjustment to seconds font
        if (fontSizeAdjust == 1) { secFont = Graphics.FONT_LARGE; }
        else if (fontSizeAdjust == -1) { secFont = Graphics.FONT_SMALL; }
        var labelFontH = Graphics.getFontHeight(labelFont);

        // LCD panel dimensions — wider and shorter for rectangular look
        var lcdW = (width * 0.78).toNumber();
        var lcdH = (height * 0.44).toNumber();
        var lcdX = cx - lcdW / 2;
        var lcdY = cy - lcdH / 2;
        var inset = (lcdW * 0.05).toNumber();

        // LCD colours — swap for low power mode (black bg, grey text)
        var lcdBg;
        var lcdColour;
        var lcdDimColour;
        if (isAwake) {
            lcdBg = 0xC0C0C0;
            lcdColour = 0x000000;
            lcdDimColour = 0x999999;
        } else {
            lcdBg = 0x000000;
            lcdColour = 0xC0C0C0;
            lcdDimColour = 0x666666;
        }

        // Calculate available time area — time is centered between date row and LCD bottom
        // so it can overflow slightly; use generous allowance
        var availableTimeH = lcdH * 0.75;

        // Choose the largest time font that fits in the available space
        var timeFontSize = Graphics.FONT_NUMBER_MEDIUM;
        // Apply font size adjustment
        if (fontSizeAdjust == 1) { timeFontSize = Graphics.FONT_NUMBER_HOT; }
        else if (fontSizeAdjust == -1) { timeFontSize = Graphics.FONT_NUMBER_MILD; }
        var timeFontH = Graphics.getFontHeight(timeFontSize);
        if (timeFontH > availableTimeH) {
            timeFontSize = Graphics.FONT_NUMBER_MEDIUM;
            timeFontH = Graphics.getFontHeight(timeFontSize);
        }
        if (timeFontH > availableTimeH) {
            timeFontSize = Graphics.FONT_NUMBER_MILD;
            timeFontH = Graphics.getFontHeight(timeFontSize);
        }
        if (timeFontH > availableTimeH) {
            timeFontSize = Graphics.FONT_LARGE;
            timeFontH = Graphics.getFontHeight(timeFontSize);
        }

        // Draw LCD panel background
        targetDc.setColor(lcdBg, lcdBg);
        targetDc.fillRoundedRectangle(lcdX, lcdY, lcdW, lcdH, 18);
        targetDc.setColor(isAwake ? 0x555555 : 0x333333, Graphics.COLOR_TRANSPARENT);
        targetDc.drawRoundedRectangle(lcdX, lcdY, lcdW, lcdH, 18);

        // ---- VERTICAL LAYOUT — build from top down ----
        var yPos = lcdY + 2;

        // -- ROW 1: Day of week (single letters for compact spacing) --
        yPos = yPos + labelFontH / 2;
        var dayLabels = ["S", "M", "T", "W", "T", "F", "S"];
        var dayLabelsFull = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
        var dateInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var currentDow = dateInfo.day_of_week;
        var dayTotalW = lcdW - inset * 2 - 4;
        for (var i = 0; i < 7; i++) {
            var dayX = (lcdX + inset + 2 + dayTotalW * (i + 0.5) / 7.0).toNumber();
            if ((i + 1) == currentDow) {
                // Show full 2-letter label for current day, highlighted
                var dw = dc.getTextWidthInPixels(dayLabelsFull[i], labelFont) + 6;
                var dh = labelFontH + 2;
                targetDc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
                targetDc.fillRectangle(dayX - dw / 2, yPos - dh / 2, dw, dh);
                targetDc.setColor(lcdBg, Graphics.COLOR_TRANSPARENT);
                targetDc.drawText(dayX, yPos, labelFont, dayLabelsFull[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                targetDc.setColor(lcdDimColour, Graphics.COLOR_TRANSPARENT);
                targetDc.drawText(dayX, yPos, labelFont, dayLabels[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
        yPos = yPos + labelFontH / 2 + 1;

        // -- Separator line --
        targetDc.setColor(lcdDimColour, Graphics.COLOR_TRANSPARENT);
        targetDc.drawLine(lcdX + 4, yPos, lcdX + lcdW - 4, yPos);
        yPos = yPos + 2;

        // -- ROW 2: AM/PM (left) + Date (center) + Battery (right) --
        yPos = yPos + labelFontH / 2;
        var minutes = clockTime.min;
        var hours = clockTime.hour;
        var isPM = (hours >= 12);

        // AM/PM shown side by side, active one highlighted, positioned at date row
        var ampmX = lcdX + inset;
        targetDc.setColor(isPM ? lcdDimColour : lcdColour, Graphics.COLOR_TRANSPARENT);
        targetDc.drawText(ampmX, yPos, labelFont, "AM", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var amW = dc.getTextWidthInPixels("AM", labelFont);
        targetDc.setColor(isPM ? lcdColour : lcdDimColour, Graphics.COLOR_TRANSPARENT);
        targetDc.drawText(ampmX + amW + 1, yPos, labelFont, "PM", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var infoLong = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var monthStr = infoLong.month.toString().substring(0, 3).toUpper();
        var dateStr = dateInfo.day.format("%d");
        targetDc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
        targetDc.drawText(cx + lcdW * 0.06, yPos, labelFont, monthStr + " " + dateStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var ampmRowY = yPos;
        yPos = yPos + labelFontH / 2 + 1;

        // -- MAIN TIME: centred between date row bottom and LCD bottom, nudged down --
        var timeAreaTop = yPos;
        var timeAreaBot = lcdY + lcdH;
        var timeY = (timeAreaTop + timeAreaBot) / 2 + labelFontH * 0.5;

        // -- Data field positions --
        var ampmBottom = ampmRowY + labelFontH / 2;
        var timeTop = timeY - timeFontH / 2;
        var dataY = ampmBottom + (timeTop - ampmBottom) * 0.45;
        var symSize = labelFontH * 0.28;
        var symY = dataY - symSize * 0.2;

        // -- Right data field: centered vertically between AM/PM row and digital time --
        if (casioDataField != 0) {
            var dataStr = dataStringNumber(casioDataField);
            if ((casioDataField == 2 || casioDataField == 23) && _batteryColourLevelOn) {
                var lvl = (casioDataField == 23 && bodyBattery != null) ? bodyBattery.toNumber() : batteryLevel;
                targetDc.setColor(setBatteryColour(lvl), Graphics.COLOR_TRANSPARENT);
            } else {
                targetDc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
            }
            // Draw symbol to the right of the data text for supported fields
            var hasSymbol = hasSymbolField(casioDataField);
            var innerRight = lcdX + lcdW - inset;
            if (hasSymbol) {
                // Strip the trailing text suffix (e.g. %, s, f, b) — replaced by the symbol
                if (dataStr.length() > 0) {
                    dataStr = dataStr.substring(0, dataStr.length() - 1);
                }
                drawSymbol(targetDc, innerRight, symY, symSize, casioDataField);
                var symWidth = getSymbolLeftExtent(symSize, casioDataField) + symSize * 0.3;
                targetDc.drawText(innerRight - symWidth, dataY, labelFont, dataStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                targetDc.drawText(innerRight, dataY, labelFont, dataStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // -- Left data field: mirrored on left side --
        if (casioDataFieldLeft != 0) {
            var dataStrL = dataStringNumber(casioDataFieldLeft);
            if ((casioDataFieldLeft == 2 || casioDataFieldLeft == 23) && _batteryColourLevelOn) {
                var lvlL = (casioDataFieldLeft == 23 && bodyBattery != null) ? bodyBattery.toNumber() : batteryLevel;
                targetDc.setColor(setBatteryColour(lvlL), Graphics.COLOR_TRANSPARENT);
            } else {
                targetDc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
            }
            var hasSymbolL = hasSymbolField(casioDataFieldLeft);
            var innerLeft = lcdX + inset;
            if (hasSymbolL) {
                if (dataStrL.length() > 0) {
                    dataStrL = dataStrL.substring(0, dataStrL.length() - 1);
                }
                targetDc.drawText(innerLeft, dataY, labelFont, dataStrL, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                drawSymbol(targetDc, innerLeft + targetDc.getTextWidthInPixels(dataStrL, labelFont) + symSize * 0.3 + getSymbolLeftExtent(symSize, casioDataFieldLeft), symY, symSize, casioDataFieldLeft);
            } else {
                targetDc.drawText(innerLeft, dataY, labelFont, dataStrL, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        if (twelveHourTimeOn) {
            if (hours > 12) { hours = hours - 12; }
            if (hours == 0) { hours = 12; }
            timeString = hours.format("%d") + ":" + minutes.format("%02d");
        } else {
            if (hours == 24) { hours = 0; }
            timeString = hours.format("%02d") + ":" + minutes.format("%02d");
        }

        var timeWidth = dc.getTextWidthInPixels(timeString, timeFontSize);
        var secStr = clockTime.sec.format("%02d");
        var secWidth = dc.getTextWidthInPixels(secStr, secFont);
        var gap = 2;
        var totalTimeWidth = timeWidth + gap + secWidth;
        var maxInnerW = lcdW;

        // If time + seconds don't fit, try each smaller font until they do
        if (totalTimeWidth > maxInnerW && timeFontSize != Graphics.FONT_NUMBER_MEDIUM) {
            timeFontSize = Graphics.FONT_NUMBER_MEDIUM;
            timeFontH = Graphics.getFontHeight(timeFontSize);
            timeWidth = dc.getTextWidthInPixels(timeString, timeFontSize);
            totalTimeWidth = timeWidth + gap + secWidth;
        }
        if (totalTimeWidth > maxInnerW && timeFontSize != Graphics.FONT_NUMBER_MILD) {
            timeFontSize = Graphics.FONT_NUMBER_MILD;
            timeFontH = Graphics.getFontHeight(timeFontSize);
            timeWidth = dc.getTextWidthInPixels(timeString, timeFontSize);
            totalTimeWidth = timeWidth + gap + secWidth;
        }
        if (totalTimeWidth > maxInnerW && timeFontSize != Graphics.FONT_LARGE) {
            timeFontSize = Graphics.FONT_LARGE;
            timeFontH = Graphics.getFontHeight(timeFontSize);
            timeWidth = dc.getTextWidthInPixels(timeString, timeFontSize);
            totalTimeWidth = timeWidth + gap + secWidth;
        }
        // If still too wide, step seconds font down
        if (totalTimeWidth > maxInnerW && secFont != Graphics.FONT_SMALL) {
            secFont = Graphics.FONT_SMALL;
            secWidth = dc.getTextWidthInPixels(secStr, secFont);
            totalTimeWidth = timeWidth + gap + secWidth;
        }
        if (totalTimeWidth > maxInnerW && secFont != Graphics.FONT_TINY) {
            secFont = Graphics.FONT_TINY;
            secWidth = dc.getTextWidthInPixels(secStr, secFont);
            totalTimeWidth = timeWidth + gap + secWidth;
        }

        var timeStartX = cx - totalTimeWidth / 2 + timeWidth / 2;

        targetDc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
        targetDc.drawText(timeStartX, timeY, timeFontSize, timeString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Seconds are drawn exclusively by onPartialUpdate to avoid double-drawing

        // -- Bottom label: 12H / 24H right-aligned, small --
        var bottomLabelY = lcdY + lcdH - 2 - labelFontH / 2;
        targetDc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        var modeStr = twelveHourTimeOn ? "12H" : "24H";
        // Draw smaller by using a scaled-down approach: position at very bottom
        targetDc.drawText(lcdX + lcdW - inset, lcdY + lcdH - 2, labelFont, modeStr, Graphics.TEXT_JUSTIFY_RIGHT);

        // Bluetooth dot bottom-left
        if (bluetoothStatusOn) {
            targetDc.setColor(phoneConnected ? Graphics.COLOR_BLUE : lcdDimColour, Graphics.COLOR_TRANSPARENT);
            targetDc.fillCircle(lcdX + inset + 3, bottomLabelY, 3);
        }

        // DND indicator — draw bell symbol in red
        if (doNotDisturbOn && dndSupported && doNotDisturbStatus) {
            targetDc.setColor(0xE04040, Graphics.COLOR_TRANSPARENT);
            var dndSymSize = labelFontH * 0.35;
            drawSymbol(targetDc, lcdX + lcdW - inset - dndSymSize * 0.5, bottomLabelY - labelFontH + dndSymSize * 1.5, dndSymSize, 10);
        }

        // ===== OUTSIDE LCD =====

        // "CASIO" above LCD
        var casioY = (lcdY * 0.22).toNumber();
        var topTextY = (lcdY * 0.30).toNumber();
        targetDc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        targetDc.drawText(cx, topTextY, Graphics.FONT_SMALL, topText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // "ALARM CHRONO" below CASIO in yellow
        var smallFontHBrand = Graphics.getFontHeight(Graphics.FONT_SMALL);
        targetDc.setColor(0xD0A830, Graphics.COLOR_TRANSPARENT);
        targetDc.drawText(cx, casioY + smallFontHBrand - 2, labelFont, "ALARM  CHRONO", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // "WATER RESIST" below LCD
        var waterResistY = lcdY + lcdH + ((height - lcdY - lcdH) / 2).toNumber() + 4;
        targetDc.setColor(0xD0A830, Graphics.COLOR_TRANSPARENT);
        targetDc.drawText(cx, waterResistY, labelFont, "WATER RESIST", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ===== INNER BEZEL — arcs left/right, straight lines top/bottom =====
        var alarmChronoY = casioY + smallFontHBrand - 2;
        var bezelTop = alarmChronoY + labelFontH / 2 + 2;
        var bezelBot = waterResistY - labelFontH / 2 - 6;
        // Arc radius = distance from center to 5% from the edge
        var arcR = (cx * 0.95).toNumber();
        // Vertical distance from cy to top/bottom lines
        var arcDyTop = cy - bezelTop;
        var arcDyBot = bezelBot - cy;
        // Compute arc angles (round to nearest for clean join with lines)
        var halfAngleTop = Math.round(Math.asin(arcDyTop.toFloat() / arcR) * 180.0 / Math.PI).toNumber();
        var halfAngleBot = Math.round(Math.asin(arcDyBot.toFloat() / arcR) * 180.0 / Math.PI).toNumber();
        // Derive line endpoints from the ceiled angles so they match exactly where arcs end
        var halfAngleTopRad = halfAngleTop.toFloat() * Math.PI / 180.0;
        var halfAngleBotRad = halfAngleBot.toFloat() * Math.PI / 180.0;
        var dxTop = Math.round(arcR * Math.cos(halfAngleTopRad)).toNumber();
        var dxBot = Math.round(arcR * Math.cos(halfAngleBotRad)).toNumber();
        var lineLeftTop = cx - dxTop;
        var lineLeftBot = cx - dxBot;
        var lineRightTop = cx + dxTop;
        var lineRightBot = cx + dxBot;
        targetDc.setPenWidth(2);
        targetDc.setColor(isAwake ? Graphics.COLOR_WHITE : 0x999999, Graphics.COLOR_TRANSPARENT);
        targetDc.drawLine(lineLeftTop, bezelTop, lineRightTop, bezelTop);
        targetDc.drawLine(lineLeftBot, bezelBot, lineRightBot, bezelBot);
        // Left arc centered at cx=0 relative, so arc center is at (cx, cy) with radius arcR
        // sweeping from top angle to bottom angle on the left side
        targetDc.drawArc(cx, cy, arcR, Graphics.ARC_COUNTER_CLOCKWISE, 180 - halfAngleTop, 180 + halfAngleBot);
        // Right arc
        targetDc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, halfAngleTop, 360 - halfAngleBot);

        // Move bar
        var moveBarSetting = false;
        try { var v = Application.Properties.getValue("moveBarOn"); if (v != null) { moveBarSetting = v; } } catch (e) {}
        if (moveBarSetting) {
            if (cachedActivityMonitorInfo != null) {
                var moveBarL = cachedActivityMonitorInfo.moveBarLevel;
                targetDc.setPenWidth(3);
                if (moveBarL > 0) {
                    targetDc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                    targetDc.drawArc(cx, cy, cx - 5, Graphics.ARC_CLOCKWISE, 91, 269);
                }
                if (moveBarL > 1) {
                    targetDc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                    targetDc.drawArc(cx, cy, cx - 5, Graphics.ARC_CLOCKWISE, 270, 270 - (moveBarL - 1) * 180 / 4);
                }
                targetDc.setPenWidth(1);
            }
        }

		drawBackground(dc);

        // Draw seconds on top via partial update mechanism
        onPartialUpdate(dc);

		fullScreenRefresh = false;
    }
    

    function drawBackground(dc) {
    // Draw the watch face background to the actual screen from from the buffers.
    // onUpdate uses this method to transfer newly rendered Buffered Bitmaps to the main display.
    // onPartialUpdate uses this to write the background over the second hand from the previous
    // second before outputing the new one, however only in the previous clipping region set in onPartialUpdate.

        //If we have an offscreen buffer that has been written to
        //draw it to the screen.
        if( null != offscreenBuffer ) {dc.drawBitmap(0, 0, offscreenBuffer);}

        // Draw calculator overlay if active
        if (calculatorActive) {
            drawCalculatorOverlay(dc);
        }

        // Draw stopwatch overlay if active
        if (stopwatchActive) {
            drawStopwatchOverlay(dc);
        }
    }

    function drawCalculatorOverlay(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w * 0.45).toNumber();
        var pad = 2;
        var inset = 4;
        var innerPad = 3;
        var totalRows = 7; // display, close, 4 button rows, equals
        var totalH = 2 * r;
        var rowH = ((totalH - innerPad * (totalRows + 1)) / totalRows).toNumber();
        var circleTop = cy - r;
        var calcButtons = ["7","8","9","/","4","5","6","x","1","2","3","-","C","0",".","+","="];

        // Black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Subtle circle outline
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);

        // Pre-compute uniform width for button rows 2-5 using the narrowest chord
        var btnHalfW = r; // will shrink to narrowest
        for (var bi = 2; bi < 6; bi++) {
            var bMidY = circleTop + innerPad + bi * (rowH + innerPad) + rowH / 2;
            var bDy = bMidY - cy;
            if (bDy * bDy < r * r) {
                var hw = Math.sqrt(r * r - bDy * bDy).toNumber() - inset;
                if (hw < btnHalfW) { btnHalfW = hw; }
            }
        }

        for (var ri = 0; ri < totalRows; ri++) {
            var yPos = circleTop + innerPad + ri * (rowH + innerPad);
            var midY = yPos + rowH / 2;
            var dy = midY - cy;
            var dySq = dy * dy;
            var rSq = r * r;
            if (dySq >= rSq) { continue; }
            var halfW = (ri >= 2 && ri <= 5) ? btnHalfW : Math.sqrt(rSq - dySq).toNumber() - inset;
            var rowStartX = cx - halfW;
            var rowW = halfW * 2;

            if (ri == 0) {
                // Display bar
                dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(rowStartX, yPos, rowW, rowH, 4);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(rowStartX + rowW - 6, yPos + rowH / 2, Graphics.FONT_SMALL, calcDisplayText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            } else if (ri == 1) {
                // Close button
                dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(rowStartX, yPos, rowW, rowH, 4);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, yPos + rowH / 2, Graphics.FONT_XTINY, "CLOSE", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else if (ri < 6) {
                // 4 buttons per row
                var btnRow = ri - 2;
                var btnW = ((rowW - pad * 3) / 4).toNumber();
                for (var col = 0; col < 4; col++) {
                    var btnIdx = btnRow * 4 + col;
                    var bx = rowStartX + col * (btnW + pad);
                    var label = calcButtons[btnIdx];
                    var isActiveOp = false;
                    if (label.equals("C")) {
                        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
                    } else if (label.equals("+") || label.equals("-") || label.equals("x") || label.equals("/")) {
                        if (calcPendingOp != null && calcPendingOp.equals(label) && calcNewInput) {
                            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                            isActiveOp = true;
                        } else {
                            dc.setColor(0xDD8800, Graphics.COLOR_TRANSPARENT);
                        }
                    } else {
                        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                    }
                    dc.fillRoundedRectangle(bx, yPos, btnW, rowH, 3);
                    dc.setColor(isActiveOp ? 0xDD8800 : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(bx + btnW / 2, yPos + rowH / 2, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            } else {
                // Equals and % buttons side by side
                var eqW = ((rowW - pad) * 3 / 4).toNumber();
                var pctW = rowW - eqW - pad;
                dc.setColor(0x33AA33, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(rowStartX, yPos, eqW, rowH, 3);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(rowStartX + eqW / 2, yPos + rowH / 2, Graphics.FONT_XTINY, "=", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(0xDD8800, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(rowStartX + eqW + pad, yPos, pctW, rowH, 3);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(rowStartX + eqW + pad + pctW / 2, yPos + rowH / 2, Graphics.FONT_XTINY, "%", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    function drawStopwatchOverlay(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w * 0.45).toNumber();
        var inset = 4;
        var innerPad = 3;
        var btnH = (r * 0.35).toNumber(); // button height for CLOSE, START, RESET

        // Black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Circle outline
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);

        // Compute elapsed time
        var total = stopwatchElapsed;
        if (stopwatchRunning) {
            total = total + (System.getTimer() - stopwatchStartTime);
        }
        var tenths = (total % 1000) / 100;
        var secs = total / 1000;
        var mins = secs / 60;
        secs = secs % 60;
        var timeStr = mins.format("%02d") + ":" + secs.format("%02d");
        var tenthStr = "." + tenths.format("%d");

        // === ROW 0: CLOSE button at the top ===
        var closeY = cy - r + (r * 0.18).toNumber();
        var closeMidY = closeY + btnH / 2;
        var closeDy = closeMidY - cy;
        var closeHalfW = Math.sqrt(r * r - closeDy * closeDy).toNumber() - inset;
        var closeX = cx - closeHalfW;
        var closeW = closeHalfW * 2;
        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(closeX, closeY, closeW, btnH, 4);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, closeMidY, Graphics.FONT_XTINY, "CLOSE", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // === CENTER: LCD-style display showing MM:SS.t ===
        var lcdTop = closeY + btnH + innerPad * 2;
        var btnRowY = cy + r - (r * 0.18).toNumber() - btnH;
        var lcdBot = btnRowY - innerPad * 2;
        var lcdH = lcdBot - lcdTop;
        var lcdW = (w * 0.78).toNumber();
        var lcdX = cx - lcdW / 2;

        // LCD background (Casio-style grey)
        dc.setColor(0xC0C0C0, 0xC0C0C0);
        dc.fillRoundedRectangle(lcdX, lcdTop, lcdW, lcdH, 12);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(lcdX, lcdTop, lcdW, lcdH, 12);

        // "STOPWATCH" label at top of LCD
        var labelFont = Graphics.FONT_XTINY;
        var labelFontH = Graphics.getFontHeight(labelFont);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lcdTop + labelFontH / 2 + 2, labelFont, "STOPWATCH", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Choose largest font that fits for MM:SS
        var availH = lcdH * 0.70;
        var timeFontSize = Graphics.FONT_NUMBER_HOT;
        if (Graphics.getFontHeight(timeFontSize) > availH) {
            timeFontSize = Graphics.FONT_NUMBER_THAI_HOT;
        }
        if (Graphics.getFontHeight(timeFontSize) > availH) {
            timeFontSize = Graphics.FONT_NUMBER_MILD;
        }
        if (Graphics.getFontHeight(timeFontSize) > availH) {
            timeFontSize = Graphics.FONT_LARGE;
        }
        var timeFontH = Graphics.getFontHeight(timeFontSize);

        // Position time vertically centered in lower portion of LCD
        var timeY = lcdTop + labelFontH + 2 + (lcdH - labelFontH - 2) / 2;

        // Draw MM:SS in large font + .t in smaller font, all in black on grey LCD
        var secFont = Graphics.FONT_MEDIUM;
        var secFontH = Graphics.getFontHeight(secFont);
        var mainW = dc.getTextWidthInPixels(timeStr, timeFontSize);
        var tenthW = dc.getTextWidthInPixels(tenthStr, secFont);
        var totalW = mainW + tenthW;
        var timeStartX = cx - totalW / 2 + mainW / 2;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(timeStartX, timeY, timeFontSize, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Tenths aligned to baseline of main time
        var timeDescent = Graphics.getFontDescent(timeFontSize);
        var secDescent = Graphics.getFontDescent(secFont);
        var tenthY = timeY + timeFontH / 2 - timeDescent - secFontH + secDescent;
        dc.drawText(timeStartX + mainW / 2, tenthY, secFont, tenthStr, Graphics.TEXT_JUSTIFY_LEFT);

        // === ROW 2: START and RESET buttons side by side at the bottom ===
        var btnMidY = btnRowY + btnH / 2;
        var btnDy = btnMidY - cy;
        var btnHalfW = Math.sqrt(r * r - btnDy * btnDy).toNumber() - inset;
        var btnRowX = cx - btnHalfW;
        var btnRowW = btnHalfW * 2;
        var btnGap = 4;
        var startW = ((btnRowW - btnGap) / 2).toNumber();
        var resetW = btnRowW - startW - btnGap;

        // START / STOP button (left)
        if (stopwatchRunning) {
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x33AA33, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRoundedRectangle(btnRowX, btnRowY, startW, btnH, 4);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var startLabel = stopwatchRunning ? "STOP" : "START";
        dc.drawText(btnRowX + startW / 2, btnMidY, Graphics.FONT_XTINY, startLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // RESET button (right)
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        var resetX = btnRowX + startW + btnGap;
        dc.fillRoundedRectangle(resetX, btnRowY, resetW, btnH, 4);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(resetX + resetW / 2, btnMidY, Graphics.FONT_XTINY, "RESET", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onPartialUpdate( dc ) {
        if (calculatorActive) { return; }
        if (stopwatchActive) {
            if (stopwatchRunning) { WatchUi.requestUpdate(); }
            return;
        }
        if (screenCenterPoint == null) { return; }
        if ((isAwake && wakeTime) || lowPowerSeconds) {
            // Refresh heart rate every second when awake
            var activityInfoHR = Activity.getActivityInfo();
            if (activityInfoHR != null && activityInfoHR has :currentHeartRate && activityInfoHR.currentHeartRate != null) {
                cachedHeartRate = activityInfoHR.currentHeartRate;
                lastCurrentHeartRate = cachedHeartRate;
            }
            activityInfoHR = null;

            if (!fullScreenRefresh) {
                drawBackground(dc);
            }
            var secStr = System.getClockTime().sec.format("%02d");
            var secFont = Graphics.FONT_MEDIUM;
            // Apply font size adjustment to seconds font
            if (fontSizeAdjust == 1) { secFont = Graphics.FONT_LARGE; }
            else if (fontSizeAdjust == -1) { secFont = Graphics.FONT_SMALL; }
            var labelFont = Graphics.FONT_XTINY;
            var lcdColour;
            var lcdBg;
            if (isAwake) {
                lcdColour = 0x000000;
                lcdBg = 0xC0C0C0;
            } else {
                lcdColour = 0xC0C0C0;
                lcdBg = 0x000000;
            }

            var w = dc.getWidth();
            var h = dc.getHeight();
            var cx = w / 2;

            // Recalculate LCD geometry to match onUpdate
            var lcdW = (w * 0.78).toNumber();
            var lcdH = (h * 0.44).toNumber();
            var lcdX = cx - lcdW / 2;
            var lcdY = h / 2 - lcdH / 2;
            var inset = (lcdW * 0.05).toNumber();

            var labelFontH = Graphics.getFontHeight(labelFont);

            var availableTimeH = lcdH * 0.75;

            var timeFontSize = Graphics.FONT_NUMBER_MEDIUM;
            // Apply font size adjustment
            if (fontSizeAdjust == 1) { timeFontSize = Graphics.FONT_NUMBER_HOT; }
            else if (fontSizeAdjust == -1) { timeFontSize = Graphics.FONT_NUMBER_MILD; }
            var timeFontH = Graphics.getFontHeight(timeFontSize);
            if (timeFontH > availableTimeH) {
                timeFontSize = Graphics.FONT_NUMBER_MEDIUM;
                timeFontH = Graphics.getFontHeight(timeFontSize);
            }
            if (timeFontH > availableTimeH) {
                timeFontSize = Graphics.FONT_NUMBER_MILD;
                timeFontH = Graphics.getFontHeight(timeFontSize);
            }
            if (timeFontH > availableTimeH) {
                timeFontSize = Graphics.FONT_LARGE;
                timeFontH = Graphics.getFontHeight(timeFontSize);
            }

            var secFontH = Graphics.getFontHeight(secFont);

            // Rebuild yPos to find timeY and ampmRowY
            var ampmRowY = lcdY + 2 + labelFontH + 1 + 2 + labelFontH / 2;
            var yPos = ampmRowY + labelFontH / 2 + 1;
            var timeAreaBot = lcdY + lcdH;
            var timeY = (yPos + timeAreaBot) / 2 + labelFontH * 0.5;

            // -- Redraw data field if heart rate is the active field (right) --
            var ampmBottom = ampmRowY + labelFontH / 2;
            var timeTop = timeY - timeFontH / 2;
            var dataY = ampmBottom + (timeTop - ampmBottom) * 0.45;
            var symSize = labelFontH * 0.28;

            // Skip heart rate redraws during full screen refresh — onUpdate() already drew them
            if (!fullScreenRefresh && casioDataField == 8) {
                var innerRight = lcdX + lcdW - inset;
                var symWidth = getSymbolLeftExtent(symSize, casioDataField) + symSize * 0.3;
                var textRight = (innerRight - symWidth).toNumber();

                // Clip and clear only the text area (symbol stays from onUpdate)
                var maxTextW = dc.getTextWidthInPixels("199", labelFont) + 4;
                var dfClipX = (textRight - maxTextW).toNumber();
                var dfClipY = (dataY - labelFontH / 2 - 1).toNumber();
                var dfClipW = (maxTextW + 2).toNumber();
                var dfClipH = (labelFontH + 2).toNumber();
                dc.setClip(dfClipX, dfClipY, dfClipW, dfClipH);
                dc.setColor(lcdBg, lcdBg);
                dc.fillRectangle(dfClipX, dfClipY, dfClipW, dfClipH);

                var dataStr = dataStringNumber(casioDataField);
                dc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
                if (dataStr.length() > 0) {
                    dataStr = dataStr.substring(0, dataStr.length() - 1);
                }
                dc.drawText(textRight, dataY, labelFont, dataStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.clearClip();
            }

            // -- Redraw data field if heart rate is the active field (left) --
            if (!fullScreenRefresh && casioDataFieldLeft == 8) {
                var innerLeft = lcdX + inset;

                var maxTextWL = dc.getTextWidthInPixels("199", labelFont) + 4;
                var dfClipXL = innerLeft;
                var dfClipYL = (dataY - labelFontH / 2 - 1).toNumber();
                var dfClipWL = (maxTextWL + 2).toNumber();
                var dfClipHL = (labelFontH + 2).toNumber();
                dc.setClip(dfClipXL, dfClipYL, dfClipWL, dfClipHL);
                dc.setColor(lcdBg, lcdBg);
                dc.fillRectangle(dfClipXL, dfClipYL, dfClipWL, dfClipHL);

                var dataStrL = dataStringNumber(casioDataFieldLeft);
                dc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
                if (dataStrL.length() > 0) {
                    dataStrL = dataStrL.substring(0, dataStrL.length() - 1);
                }
                dc.drawText(innerLeft, dataY, labelFont, dataStrL, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.clearClip();
            }

            // -- Redraw seconds --
            var timeWidth = dc.getTextWidthInPixels(timeString != null ? timeString : "00:00", timeFontSize);
            var secWidth = dc.getTextWidthInPixels(secStr, secFont);
            var gap = 2;
            var totalTimeWidth = timeWidth + gap + secWidth;
            var maxInnerW = lcdW;

            // Match the width-fitting logic from onUpdate
            if (totalTimeWidth > maxInnerW && timeFontSize != Graphics.FONT_NUMBER_MEDIUM) {
                timeFontSize = Graphics.FONT_NUMBER_MEDIUM;
                timeFontH = Graphics.getFontHeight(timeFontSize);
                timeWidth = dc.getTextWidthInPixels(timeString != null ? timeString : "00:00", timeFontSize);
                totalTimeWidth = timeWidth + gap + secWidth;
            }
            if (totalTimeWidth > maxInnerW && timeFontSize != Graphics.FONT_NUMBER_MILD) {
                timeFontSize = Graphics.FONT_NUMBER_MILD;
                timeFontH = Graphics.getFontHeight(timeFontSize);
                timeWidth = dc.getTextWidthInPixels(timeString != null ? timeString : "00:00", timeFontSize);
                totalTimeWidth = timeWidth + gap + secWidth;
            }
            if (totalTimeWidth > maxInnerW && timeFontSize != Graphics.FONT_LARGE) {
                timeFontSize = Graphics.FONT_LARGE;
                timeFontH = Graphics.getFontHeight(timeFontSize);
                timeWidth = dc.getTextWidthInPixels(timeString != null ? timeString : "00:00", timeFontSize);
                totalTimeWidth = timeWidth + gap + secWidth;
            }
            if (totalTimeWidth > maxInnerW && secFont != Graphics.FONT_SMALL) {
                secFont = Graphics.FONT_SMALL;
                secFontH = Graphics.getFontHeight(secFont);
                secWidth = dc.getTextWidthInPixels(secStr, secFont);
                totalTimeWidth = timeWidth + gap + secWidth;
            }
            if (totalTimeWidth > maxInnerW && secFont != Graphics.FONT_TINY) {
                secFont = Graphics.FONT_TINY;
                secFontH = Graphics.getFontHeight(secFont);
                secWidth = dc.getTextWidthInPixels(secStr, secFont);
                totalTimeWidth = timeWidth + gap + secWidth;
            }

            var timeStartX = w / 2 - totalTimeWidth / 2 + timeWidth / 2;
            var secX = timeStartX + timeWidth / 2 + gap;
            var timeDescent = Graphics.getFontDescent(timeFontSize);
            var secDescent = Graphics.getFontDescent(secFont);
            var secY = timeY + timeFontH / 2 - timeDescent - secFontH + secDescent;

            var secondsHeight = secFontH;
            dc.setClip(secX, secY, secWidth + 5, secondsHeight + 5);
            dc.setColor(lcdColour, Graphics.COLOR_TRANSPARENT);
            dc.drawText(secX, secY, secFont, secStr, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

	function setBatteryColour(level) {
		if (level < 20) {return Graphics.COLOR_RED;}
		else if (level < 50) {return Graphics.COLOR_YELLOW;}
		else {return Graphics.COLOR_GREEN;}
	}

	function setBodyBatteryColour(level) {
		if (level < 26) {return Graphics.COLOR_RED;}
		else if (level < 51) {return Graphics.COLOR_ORANGE;}
		else if (level < 76) {return Graphics.COLOR_YELLOW;}
		else {return Graphics.COLOR_GREEN;}
	}

	// Returns true if the given field number has an associated symbol icon
	private function hasSymbolField(n) {
		return (n == 2 || n == 6 || n == 7 || n == 8 || n == 9 || n == 10 || n == 12 || n == 13 || n == 23 || n == 26 || n == 27);
	}

	// Returns how far left of the anchor point (x) each symbol extends,
	// so callers can position text with a consistent gap.
	private function getSymbolLeftExtent(size, number) {
		if (number == 2)  { return size * 1.375; } // Battery (1.25x scaled, bx offset)
		if (number == 6)  { return size * 0.98; }  // Steps (2x scaled footprints)
		if (number == 7)  { return size * 0.75; }  // Floors (stairs)
		if (number == 8)  { return size * 1.05; }  // Heart
		if (number == 9)  { return size * 1.2; }   // Notification (envelope)
		if (number == 10) { return size * 0.81; }  // Alarm (bell)
		if (number == 12) { return size * 0.5; }   // Sunrise
		if (number == 13) { return size * 0.5; }   // Sunset/moon
		if (number == 23) { return size * 1.2; }   // Body battery (person)
		if (number == 26 || number == 27) { return size * 1.45; } // Stopwatch
		return size * 1.0;
	}

	// Lazy allocation — only build polygons for the requested symbol number
	// Eliminates array allocations per call, significant memory saving on constrained devices
	private function drawSymbol(dc, x, y, size, number) 
	{
		// Nudge certain symbols down slightly to align with text baseline
		if (number == 2 || number == 6 || number == 7 || number == 12 || number == 26 || number == 27) {
			y = y + size * 0.2;
		}
		if (number == 2) {
			// Battery symbol: vertical outline + fill segments based on level
			size = size * 1.25;
			var bx = x - size * 0.55;
			var bodyLeft   = bx - size * 0.55;
			var bodyRight  = bx + size * 0.55;
			var bodyHeight = size * 1.6;
			var bodyTop    = y - bodyHeight * 0.45;
			var bodyBottom = y + bodyHeight * 0.55;
			dc.setPenWidth(2);
			dc.drawRectangle(bodyLeft, bodyTop, bodyRight - bodyLeft, bodyHeight);
			dc.fillRectangle(bx - size * 0.25, bodyTop - size * 0.25, size * 0.5, size * 0.25);
			var fillHeight = bodyHeight * batteryLevel / 100.0;
			if (_batteryColourLevelOn) {
				dc.setColor(setBatteryColour(batteryLevel), Graphics.COLOR_TRANSPARENT);
			}
			dc.fillRectangle(bodyLeft + 1, bodyBottom - fillHeight, bodyRight - bodyLeft - 2, fillHeight);
			dc.setPenWidth(1);
		} else if (number == 6) {
			// Steps — footprints (size doubled for this symbol)
			size = size * 2;
			var footOy = size * 0.35;
			var heelOyL = size * 0.15;
			var leftFoot = [
				[x - size * 0.39, y - size * 0.41 - footOy],
				[x - size * 0.48, y - size * 0.21 - footOy],
				[x - size * 0.49, y - size * 0.01 - footOy],
				[x - size * 0.4,  y + size * 0.17 - footOy],
				[x - size * 0.21, y + size * 0.23 - footOy],
				[x - size * 0.08, y + size * 0.02 - footOy],
				[x - size * 0.11, y - size * 0.19 - footOy],
				[x - size * 0.22, y - size * 0.37 - footOy]
			];
			var leftHeel = [
				[x - size * 0.36, y + size * 0.36 - heelOyL],
				[x - size * 0.38, y + size * 0.39 - heelOyL],
				[x - size * 0.34, y + size * 0.44 - heelOyL],
				[x - size * 0.29, y + size * 0.48 - heelOyL],
				[x - size * 0.23, y + size * 0.49 - heelOyL],
				[x - size * 0.18, y + size * 0.47 - heelOyL],
				[x - size * 0.14, y + size * 0.42 - heelOyL],
				[x - size * 0.09, y + size * 0.37 - heelOyL],
				[x - size * 0.12, y + size * 0.33 - heelOyL],
				[x - size * 0.17, y + size * 0.30 - heelOyL]
			];
			var rightFoot = [
				[x + size * 0.4032, y + size * -0.0018 - footOy],
				[x + size * 0.2539,  y + size * 0.0967  - footOy],
				[x + size * 0.1339, y + size * 0.3046  - footOy],
				[x + size * 0.1232, y + size * 0.4832  - footOy],
				[x + size * 0.2418, y + size * 0.5978  - footOy],
				[x + size * 0.4111,  y + size * 0.4646  - footOy],
				[x + size * 0.5311,  y + size * 0.2567  - footOy],
				[x + size * 0.5418,  y + size * 0.0782  - footOy]
			];
			var rightHeel = [
				[x - size * 0.11, y + size * 0.36 + footOy],
				[x - size * 0.13, y + size * 0.39 + footOy],
				[x - size * 0.09, y + size * 0.44 + footOy],
				[x - size * 0.04, y + size * 0.48 + footOy],
				[x + size * 0.02, y + size * 0.49 + footOy],
				[x + size * 0.07, y + size * 0.47 + footOy],
				[x + size * 0.11, y + size * 0.42 + footOy],
				[x + size * 0.16, y + size * 0.37 + footOy],
				[x + size * 0.13, y + size * 0.33 + footOy],
				[x + size * 0.08, y + size * 0.30 + footOy]
			];
			dc.fillPolygon(leftFoot);
			dc.fillPolygon(leftHeel);
			dc.fillPolygon(rightFoot);
			dc.fillPolygon(rightHeel);
		} else if (number == 7) {
			// Floors — stairs
			var stairs = [
				[x + size * 0.75,             y + size * 0.85],
				[x + size * 0.75,             y - size * 0.72],
				[x + size * 0.375,            y - size * 0.72],
				[x + size * 0.375,            y - size * 0.36],
				[x,                           y - size * 0.36],
				[x,                           y],
				[x - size * 0.375,            y],
				[x - size * 0.375,            y + size * 0.36],
				[x - size * 0.75,             y + size * 0.36],
				[x - size * 0.75,             y + size * 0.85]
			];
			dc.fillPolygon(stairs);
		} else if (number == 8) {
			// Heart
			size = size * 0.8;
			var heart = [
				[x,                y + size * 1.25],
				[x - size*0.85,    y + size * 0.35],
				[x - size*1.05,    y - size * 0.05],
				[x - size*0.85,    y - size * 0.55],
				[x - size*0.50,    y - size * 0.95],
				[x - size*0.35,    y - size * 0.85],
				[x,                y - size * 0.40],
				[x + size*0.35,    y - size * 0.85],
				[x + size*0.50,    y - size * 0.95],
				[x + size*0.85,    y - size * 0.55],
				[x + size*1.05,    y - size * 0.05],
				[x + size*0.85,    y + size * 0.35]
			];
			dc.fillPolygon(heart);
		} else if (number == 9) {
			// Notification — envelope flaps
			var flapOy = size * 0.55;
			var topFlap = [
				[x - size*1.2, y - size*1.2 * 0.5],
				[x,            y + size*1.2 * 0.5],
				[x + size*1.2, y - size*1.2 * 0.5]
			];
			var leftFlap = [
				[x - size*1.2,   y - size*1.2 * 0.5 + flapOy],
				[x,              y + size*1.2 * 0.5 + flapOy],
				[x - size*1.2,   y + size*1.2 * 0.5 + flapOy]
			];
			var rightFlap = [
				[x + size*1.2,    y - size*1.2 * 0.5 + flapOy],
				[x,               y + size*1.2 * 0.5 + flapOy],
				[x + size*1.2,    y + size*1.2 * 0.5 + flapOy]
			];
			dc.fillPolygon(topFlap);
			dc.fillPolygon(leftFlap);
			dc.fillPolygon(rightFlap);
		} else if (number == 10) {
			// Alarm — bell
			var by = y + size * 0.3;
			var bellBody = [
				[x - size * 0.36,  by - size * 1.035],
				[x - size * 0.594, by - size * 0.72],
				[x - size * 0.684, by - size * 0.36],
				[x - size * 0.612, by + size * 0.18],
				[x - size * 0.81,  by + size * 0.45],
				[x + size * 0.81,  by + size * 0.45],
				[x + size * 0.612, by + size * 0.18],
				[x + size * 0.684, by - size * 0.36],
				[x + size * 0.594, by - size * 0.72],
				[x + size * 0.36,  by - size * 1.035]
			];
			var clapper = [
				[x,                by + size * 0.6],
				[x - size * 0.2,   by + size * 0.75],
				[x,                by + size * 0.9],
				[x + size * 0.2,   by + size * 0.75],
				[x,                by + size * 0.6]
			];
			var knob = [
				[x,                by - size * 1.25],
				[x - size * 0.12,  by - size * 1.18],
				[x + size * 0.12,  by - size * 1.18]
			];
			dc.fillPolygon(bellBody);
			dc.fillPolygon(clapper);
			dc.fillPolygon(knob);
		} else if (number == 12) {
			// Sunrise — sun half-circle + horizon + rays
			var sx = x + size * 0.5;
			var sy = y + size * 0.7;
			var sunriseSun = [
				[sx - size * 0.7,  sy],
				[sx - size * 0.6,   sy - size * 0.45],
				[sx - size * 0.375, sy - size * 0.675],
				[sx,               sy - size * 0.75],
				[sx + size * 0.375, sy - size * 0.675],
				[sx + size * 0.6,   sy - size * 0.45],
				[sx + size * 0.7,  sy]
			];
			var sunriseSun_1 = [
				[sx - size , sy + size * 0.1],
				[sx + size , sy + size * 0.1],
				[sx + size , sy - size * 0.1],
				[sx - size , sy - size * 0.1]
			];
			dc.fillPolygon(sunriseSun);
			dc.fillPolygon(sunriseSun_1);
			dc.drawLine(sx, sy - size * 0.75, sx, sy - size * 1.35);
			dc.drawLine(sx - size * 0.375, sy - size * 0.675, sx - size * 0.65, sy - size * 1.2);
			dc.drawLine(sx + size * 0.375, sy - size * 0.675, sx + size * 0.65, sy - size * 1.2);
		} else if (number == 13) {
			// Sunset / moon — crescent
			var my = y + size * 0.2;
			var sunsetMoon = [
				[x - size * 0.5,  my - size],
				[x + size * 0.1,  my - size * 0.9],
				[x + size * 0.35, my - size * 0.65],
				[x + size * 0.55, my - size * 0.45],
				[x + size * 0.65, my - size * 0.3],
				[x + size * 0.7,  my],
				[x + size * 0.65, my + size * 0.3],
				[x + size * 0.55, my + size * 0.45],
				[x + size * 0.35, my + size * 0.65],
				[x + size * 0.1,  my + size * 0.9],
				[x - size * 0.5,  my + size],
				[x - size * 0.35, my + size * 0.85],
				[x - size * 0.10, my + size * 0.6],
				[x,               my],
				[x - size * 0.10, my - size * 0.6],
				[x - size * 0.35, my - size * 0.85]
			];
			dc.fillPolygon(sunsetMoon);
		} else if (number == 23) {
			// Body battery symbol - person with arms raised
			var px = x - size * 0.55;
			var personBody = [
				[px - size * 0.2,  y - size * 0.3],
				[px - size * 0.2,  y + size * 0.5],
				[px + size * 0.2,  y + size * 0.5],
				[px + size * 0.2,  y - size * 0.3]
			];
			var personLeftArm = [
				[px - size * 0.2,  y - size * 0.2],
				[px - size * 0.65, y - size * 0.9],
				[px - size * 0.5,  y - size * 1.0]
			];
			var personRightArm = [
				[px + size * 0.2,  y - size * 0.2],
				[px + size * 0.65, y - size * 0.9],
				[px + size * 0.5,  y - size * 1.0]
			];
			var personLeftLeg = [
				[px - size * 0.15, y + size * 0.5],
				[px - size * 0.4,  y + size * 1.1],
				[px - size * 0.2,  y + size * 1.1]
			];
			var personRightLeg = [
				[px + size * 0.15, y + size * 0.5],
				[px + size * 0.4,  y + size * 1.1],
				[px + size * 0.2,  y + size * 1.1]
			];
			dc.fillPolygon(personBody);
			dc.fillPolygon(personLeftArm);
			dc.fillPolygon(personRightArm);
			dc.fillPolygon(personLeftLeg);
			dc.fillPolygon(personRightLeg);
			dc.fillCircle(px, y - size * 0.55, size * 0.25);
		} else if (number == 26 || number == 27) {
			// Stopwatch — circle with button on top, hand, and motion lines
			var sx = x + size * 0.35;
			var sy = y + size * 0.15;
			var r = size * 0.85;
			dc.setPenWidth(2);
			dc.drawCircle(sx, sy, r);
			// Top button
			dc.fillRectangle(sx - size * 0.1, sy - r - size * 0.35, size * 0.2, size * 0.35);
			// Clock hand (pointing up-right)
			dc.drawLine(sx, sy, sx + r * 0.55, sy - r * 0.55);
			// Centre dot
			dc.fillCircle(sx, sy, size * 0.1);
			// Motion lines to the left
			var lx = sx - r - size * 0.3;
			dc.drawLine(lx, sy - size * 0.5, lx - size * 0.4, sy - size * 0.5);
			dc.drawLine(lx, sy, lx - size * 0.65, sy);
			dc.drawLine(lx, sy + size * 0.5, lx - size * 0.4, sy + size * 0.5);
			dc.setPenWidth(1);
		}
	}

    function dataStringNumber(textNumber) {
	// Returns the appropriate string depending on the selected field information
	// based on the users selection of the data field that has been chosen
		// Use cached clock time from onUpdate() with null fallback
        var myTime = cachedClockTime;
		if (myTime == null) { myTime = System.getClockTime(); }
		var minutes = myTime.min;
		var hours = myTime.hour;
		var hoursFraction = hours + minutes/60.0;

		// Create the appendage strings
		// Single-character suffixes so the drawing code can strip exactly 1 char
		// before drawing the polygon symbol (matches CleanAnalogPremium convention)
		var batteryString = "%";
		var stepString = "s";
		var heartString = "b";
		var notificationString = "n";
		var alarmString = "a";
		var sunriseString = " ";
		var sunsetString = " ";
		var floorsString = "f";
		var timeToRecoveryString = "h";

		var dataString = "";
        var am_pm = "";

        var totalDistance = 0;
	    //var totalDistanceMiles = 0;
	    var totalCal = 0;
		var	totalSteps = 0;
		var totalFloors = 0;
		var timeToRecovery = 0;
		var totalActivityMinutesDay = 0;
		var totalActivityMinutesWeek = 0;

		// Use cached ActivityMonitor.getInfo() (once per minute) for distance, calories
		// Do NOT call ActivityMonitor.getInfo() here — dataStringNumber() runs 10+ times per frame
		var infoActivityMonitor = cachedActivityMonitorInfo;
		if (infoActivityMonitor != null) {
			totalDistance = (infoActivityMonitor has :distance && infoActivityMonitor.distance != null) ? (infoActivityMonitor.distance)/100000.0 : 0;
			totalCal = (infoActivityMonitor has :calories && infoActivityMonitor.calories != null) ? infoActivityMonitor.calories : 0 ;
			timeToRecovery = (infoActivityMonitor has :timeToRecovery && infoActivityMonitor.timeToRecovery != null) ? infoActivityMonitor.timeToRecovery : 0;
			if (infoActivityMonitor has :activeMinutesDay && infoActivityMonitor.activeMinutesDay != null) {
				totalActivityMinutesDay = infoActivityMonitor.activeMinutesDay.total;
			}
			if (infoActivityMonitor has :activeMinutesWeek && infoActivityMonitor.activeMinutesWeek != null) {
				totalActivityMinutesWeek = infoActivityMonitor.activeMinutesWeek.total;
			}
		}

		// Steps (6) and Floors (7) fetch fresh per-second only when those fields are displayed
		if (textNumber == 6 || textNumber == 7) {
			infoActivityMonitor = ActivityMonitor.getInfo();
			if (infoActivityMonitor != null) {
				totalSteps = (infoActivityMonitor has :steps && infoActivityMonitor.steps != null) ? infoActivityMonitor.steps : 0;
				totalFloors = (infoActivityMonitor has :floorsClimbed && infoActivityMonitor.floorsClimbed != null) ? infoActivityMonitor.floorsClimbed : 0;
			}
			infoActivityMonitor = null;
		}


		switch (textNumber) {
		case 1:{// Calculate the time based on the use of timeZone or not
				if (timeZoneOn)
				{
					// Use cached clock time for timezone calculation
					var tzDelta = timeZoneOffset - (myTime.timeZoneOffset / 3600.0);
					minutes = minutes + (tzDelta - Math.floor(tzDelta))*60.0;
					if (minutes > 59){
					  minutes = minutes - 60.0;
					  hours = hours + 1.00 ;
					}
					hours = (hours + Math.floor(tzDelta)).toNumber();
					hours = hours % 24;
					if (hours < 0) { hours = hours + 24; }
				} // End of TimeZone correction section

		        // If the 12 hour time option is set then create 12 hour time representation
		        if (twelveHourTimeOn)
		        {
		         	am_pm = "am";
		 			// Set pm if after 12:00, set time to 12 hours time
		        		if ((hours>=12)&&(hours<=23)) {am_pm = "pm";}
		        		if (hours>12) {hours = hours-12;}
		        		// Make sure not to display 00:?? time for 12 hour time
		  			if (hours == 0) {hours=12;}
		 		} else {
					// now if the 12 hour time is not turned on then check if hours is 24 and make it 00
		 			if (hours==24) { hours = 0; }
		 		}
		 		// Create the time string in mm:hh[am/pm] format as per twelveHourTime being off
				dataString = hours.format("%02d")+":"+minutes.format("%02d")+am_pm;
				// Change the way the time is displayed if twelveHourTime is on
		        if (twelveHourTimeOn)
		 		{
		 			dataString = hours.format("%2d")+":"+minutes.format("%02d")+am_pm;
				}
			break;}
		case 2:{// Battery level - use cached batteryLevel from needSensorUpdate block
			dataString = batteryLevel.toString() + batteryString;
			break;}
		case 3:{// Todays distance in km - now once per minute via cachedActivityMonitorInfo
			dataString = (kmmiles==true) ? totalDistance.format("%.1f")+"k" : (totalDistance*0.621371).format("%.1f")+"m";
			break;}
		case 4:{// Total distance for past 6 days + today, in km
			// Use cached 7-day history (updated once per minute in needSensorUpdate)
			totalDistance = totalDistance + cached7DayDistance;
			dataString = (kmmiles==true) ? totalDistance.format("%.1f")+"k" : (totalDistance*0.621371).format("%.1f")+"m";
			break;}
		case 5:{dataString = totalCal + "kC"; break;}  // Total calories
		case 6:{dataString = totalSteps + stepString; break;} // Total steps
		case 7:{dataString = totalFloors + floorsString; break;} // Total stairs
		case 8:{// Heart rate - use cached value from drawBackground heart rate section
			if (cachedHeartRate != null) {
				heartRate = cachedHeartRate.toString();
			}
			dataString = heartRate + heartString;
			break;}
		case 9:{//Get the number of notifications waiting - use cached value from onUpdate()
			if (notificationCount > 0) {dataString = notificationCount.toString() + notificationString;}
			else {dataString = "";}
			break;}
		case 10:{//Get the number of alarms set - use cached value from onUpdate()
			if (alarmCount != null && alarmCount > 0) {dataString = alarmCount.toString() + alarmString;}
			else {dataString = "";}
			break;}
		case 11:{//next sun event
			if (sunrise < 0 || sunset < 0) { dataString = "--:--"; }
			else if ((hoursFraction > sunrise)&&(hoursFraction <= sunset)) 
			{dataString = Math.floor(sunset).format("%02d")+":"+((sunset-Math.floor(sunset))*60).format("%02d")+sunsetString;}
			else {
				if ((hoursFraction > sunset)&&(hoursFraction <= 24.0))
				{dataString = Math.floor(sunriseTomorrow).format("%02d")+":"+((sunriseTomorrow-Math.floor(sunriseTomorrow))*60).format("%02d")+sunriseString;}
				else {dataString = Math.floor(sunrise).format("%02d")+":"+((sunrise-Math.floor(sunrise))*60).format("%02d")+sunriseString;}
			}
			break;}
		case 12:{// Sunrise
			if (sunrise < 0) { dataString = "--:--" + sunriseString; }
			else { dataString = Math.floor(sunrise).format("%02d")+":"+((sunrise-Math.floor(sunrise))*60).format("%02d")+sunriseString; }
			break;}
		case 13:{// Sunset
			if (sunset < 0) { dataString = "--:--" + sunsetString; }
			else { dataString = Math.floor(sunset).format("%02d")+":"+((sunset-Math.floor(sunset))*60).format("%02d")+sunsetString; }
			break;}
		case 14:{// Latitude
			if (latitude == 0 ) { dataString = latitude.format("%.2f");}
			else if (latitude > 0 ){ dataString = latitude.format("%.2f")+"N";}
			else { dataString = (-1*latitude).format("%.2f")+"S";}
			break;}
		case 15:{// Longitude
			if (longitude == 0 ) {dataString = longitude.format("%.2f");}
			else if (longitude >0 ) {dataString = longitude.format("%.2f")+"E";}
			else {dataString = (-1*longitude).format("%.2f")+"W";}
			break;}
		case 16:{// Altitude - use cached value from needSensorUpdate block
			if (cachedAltitude != null) {				
				altitudeString = (metersfeet==true) ? cachedAltitude.format("%.1f")+"m" : (3.28084*cachedAltitude).format("%d")+"ft";
			}
			dataString = altitudeString; 			
			break;}
		case 17:{// mean sealevel barometric pressure - use cached value
			if (cachedMeanSeaLevelPressure != null) {
				pressureString = (cachedMeanSeaLevelPressure*arrayPressureConvert).format("%.1f");
			}
			dataString = pressureString+arrayPressureString; 			
			break;}
		case 18:{// ambient pressure - use cached value
			if (cachedAmbientPressure != null) {
				pressureString = (cachedAmbientPressure*arrayPressureConvert).format("%.1f");
			}
			dataString = pressureString+arrayPressureString; 			
			break;}
		case 19:{// history pressure - use cached values from needSensorUpdate block
			if (pressureNext != null && pressureLast != null) {
				if (pressureNext > pressureLast) {pressureHistoryString = sunriseString+(pressureNext*arrayPressureConvert).format("%.1f");}
				else if (pressureNext < pressureLast) {pressureHistoryString = sunsetString+(pressureNext*arrayPressureConvert).format("%.1f");}
				else { pressureHistoryString = (pressureNext*arrayPressureConvert).format("%.1f");}
			}
			dataString = pressureHistoryString+arrayPressureString; 			
			break;}
		case 20:{// Temperature - use cached value from needSensorUpdate block
			if (cachedTemperature != null) {
				temperatureString = (celsiusfahrenheit==true) ? cachedTemperature.format("%.1f")+"C" : (cachedTemperature*1.8+32).format("%.1f")+"F" ;
			}
			dataString = temperatureString;
			break;}
		case 21:{//sunrise and sunset
			var sunriseStr = (sunrise < 0) ? "--:--" + sunriseString : Math.floor(sunrise).format("%02d")+":"+((sunrise-Math.floor(sunrise))*60).format("%02d")+sunriseString;
			var sunsetStr = (sunset < 0) ? "--:--" + sunsetString : Math.floor(sunset).format("%02d") +":"+ ((sunset-Math.floor(sunset))*60).format("%02d")+sunsetString;
			dataString = sunriseStr + " " + sunsetStr;
			break;}
		case 22:{//latitude and longitude
			if (latitude == 0 ) { dataString = latitude.format("%.2f");}
			else if (latitude > 0 ){ dataString = latitude.format("%.2f")+"N";}
			else { dataString = (-1*latitude).format("%.2f")+"S";}
			if (longitude == 0 ) {dataString = dataString + " " + longitude.format("%.2f");}
			else if (longitude >0 ) {dataString = dataString + " " + longitude.format("%.2f")+"E";}
			else {dataString = dataString + ""+ (-1*longitude).format("%.2f")+"W";}
			break;}
		case 23:{// Body Battery - use cached value from needSensorUpdate block
			if (bodyBattery != null) {
				bodyBatteryString = bodyBattery.toNumber().toString();
			}
			dataString = bodyBatteryString + "%";
			break;}		
		case 24:{// Time to Recovery
			dataString = timeToRecovery + timeToRecoveryString;
			break;}
		case 25:{// Outside Temperature - use cached Weather API value
			if (outsideTemperature != null) {
				temperatureString = (celsiusfahrenheit==true) ? outsideTemperature.format("%.1f")+"C" : (outsideTemperature*1.8+32).format("%.1f")+"F" ;
			}
			dataString = temperatureString;
			break;}
		case 26:{// Activity minutes today
			dataString = totalActivityMinutesDay + "m";
			break;}
		case 27:{// Activity minutes this week
			dataString = totalActivityMinutesWeek + "m";
			break;}
		default:{dataString = ""; break;}
		}
		// Finally return the completed string
		return dataString;
    }

    function onEnterSleep() {
    // This method is called when the device re-enters sleep mode.
    // Set the isAwake flag to let onUpdate know it should stop rendering the second hand.
        isAwake = false;
        settingsChanged = true;
        WatchUi.requestUpdate();
        // and if you do it here, you may see "jittery seconds" when the watch face drops back to low power mode
    	// if(!partialUpdatesAllowed) {WatchUi.requestUpdate();}
    }

    function onExitSleep() {
    // This method is called when the device exits sleep mode.
    // Set the isAwake flag to let onUpdate know it should render the second hand.
        isAwake = true;
        settingsChanged = true;
         //if you are doing 1hz, there's no reason to do the Ui.reqestUpdate()
    	// (see note below too)
    	if(!partialUpdatesAllowed) {WatchUi.requestUpdate();}
    }

// START OF ROUTINES TO CALCULATE ISO WEEK NUMBER
	function julian_day(year, month, day)
	{
	    // returns what day is the first Thursday of the year
	    var a = (14 - month) / 12;
	    var y = (year + 4800 - a);
	    var m = (month + 12 * a - 3);
	    return day + ((153 * m + 2) / 5) + (365 * y) + (y / 4) - (y / 100) + (y / 400) - 32045;
	}

	function is_leap_year(year)
	{
	    // Returns true if year is a leap year
	    if (year % 4 != 0) {return false;}
	    else if (year % 100 != 0) {return true;}
	    else if (year % 400 == 0) {return true;}
	    return false;
	}

	function iso_week_number(year, month, day)
	{
		// Retuns the ISO week number
	    var first_day_of_year = julian_day(year, 1, 1);
	    var given_day_of_year = julian_day(year, month, day);
	    var day_of_week = (first_day_of_year + 3) % 7; // days past thursday
	    var week_of_year = (given_day_of_year - first_day_of_year + day_of_week + 4) / 7;

	    // week is at end of this year or the beginning of next year
	    if (week_of_year == 53) {
	        if (day_of_week == 6) {return week_of_year;}
	        else if (day_of_week == 5 && is_leap_year(year)) {return week_of_year;}
	        else {return 1;}
	    }
	    // week is in previous year, try again under that year
	    else if (week_of_year == 0) {
	        first_day_of_year = julian_day(year - 1, 1, 1);
	        day_of_week = (first_day_of_year + 3) % 7;
	        return (given_day_of_year - first_day_of_year + day_of_week + 4) / 7;
	    }
	    // any old week of the year
	    else {return week_of_year;}
	}
// END OF ROUTINES TO CALCULATE ISO WEEK NUMBERS

// SUNRISE AND SUNSET FUNCTION
    function getSunriseSunset()
	{
		// Lat North=+; South=-; Lon East=+; West=-;
		var loc;
		var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT); // get the current time
		var myTime = System.getClockTime();	// get the system clock just to be able to get the TimeZoneOffset

//        System.println("getSunriseSunset: Now=" + now.day + " Saved_day=" + today
//        	+ " Sunrise=" + Lang.format("$1$:$2$", [Math.floor(sunrise).format("%02d"), ((sunrise-Math.floor(sunrise))*60).format("%02d")])
//        	+ " Sunset=" + Lang.format("$1$:$2$", [Math.floor(sunset).format("%02d"), ((sunset-Math.floor(sunset))*60).format("%02d")])
//        	+ " Lat=" + latitude + " Lon=" + longitude);

		// The following will check if the location has changed and if it has
		// attempt to put into Storage for later use when the app restarts
		// then recalcualte the sunrise and sunset
		// If there is no info OR no current location then skip this
		var info = Activity.getActivityInfo();
		if (info != null) {
			// Get the current location
			loc = info.currentLocation;
			// If there is nothing in the current location then skip the following
			if ( loc != null )
			{	// There is a current location so convert it into Degrees
				var myLocation = loc.toDegrees();
				if (myLocation != null && myLocation.size() == 2 && (latitude!=myLocation[0])&&(longitude!=myLocation[1]))
				{ // If the latitude and longitude are different to the current location
				  // then write this to storage Storage or if no Storage make them equal
					//System.println("getSunriseSunset: the location has changed");
					if ( Toybox.Application has :Storage )
	        		{ 	// If Storage is available then write the current location to it
						Application.Storage.setValue("latitude", myLocation[0]); // Write the current location to the settings
						Application.Storage.setValue("longitude", myLocation[1]);
					}
					// Now calculate the new sunrise and sunset for this new lat/lon
					latitude = myLocation[0];
					longitude = myLocation[1];
					var sc = new SunCal();
					sc.setCurrentDate(now.year, now.month, now.day); // write the current date to the SunCal class and most important is this calculates julianDate
					sc.setPosition(latitude,longitude, myTime.timeZoneOffset / 3600f); // Set the current position and time zone offset
					sunrise = sc.calcSunrise()/60.0; // calculate Sunrise in hours.fraction
					sunriseTomorrow = sc.calcSunriseTomorrow()/60.0; 
					sunset = sc.calcSunset()/60.0; // calculate Sunset in hours.fraction
					// If the latitude or longitude have changed then exit
					// otherwise go onto check if the day has changed
					// Also update the current day while we are here
					today = now.day;
					return;
				}
			}
		}
		// If the day or timezone has changed then calcualte a new sunrise and sunset
		// Because today starts out =0, this also triggers the first calculation
		// of sunrise and sunset
		if ((today != now.day)||(todayZone !=myTime.timeZoneOffset))
		{
			//System.println("getSunriseSunset: the day or zone has changed");
			var sc = new SunCal();
			sc.setCurrentDate(now.year, now.month, now.day); // write the current date to the SunCal class and most important is this calculates julianDate
			sc.setPosition(latitude,longitude, myTime.timeZoneOffset / 3600f); // Set the current position and time zone offset
			sunrise = sc.calcSunrise()/60.0; // calculate Sunrise in hours.fraction
			sunriseTomorrow = sc.calcSunriseTomorrow()/60.0; 
			sunset = sc.calcSunset()/60.0; // calculate Sunset in hours.fraction
			today = now.day;
			todayZone = myTime.timeZoneOffset;
			// If the day has changed then exit
			return;
		}
	}
}


class AnalogDelegate extends WatchUi.WatchFaceDelegate {
    // The onPowerBudgetExceeded callback is called by the system if the
    // onPartialUpdate method exceeds the allowed power budget. If this occurs,
    // the system will stop invoking onPartialUpdate each second, so we set the
    // partialUpdatesAllowed flag here to let the rendering methods know they
    // should not be rendering a second hand.

    function initialize() {
		WatchFaceDelegate.initialize();
	}

    function onPowerBudgetExceeded(powerInfo) {
        System.println( "Average execution time: " + powerInfo.executionTimeAverage );
        System.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
        partialUpdatesAllowed = false;
    }

	function onPress(pressEvent) {
		var coords = pressEvent.getCoordinates();
		if (coords == null || coords.size() < 2) { return false; }
		var x = coords[0];
		var y = coords[1];
		var screenW = System.getDeviceSettings().screenWidth;
		var screenH = System.getDeviceSettings().screenHeight;

		if (stopwatchActive) {
			var cx = screenW / 2;
			var cy = screenH / 2;
			var r = (screenW * 0.45).toNumber();
			var btnH = (r * 0.35).toNumber();

			// CLOSE button zone (top)
			var closeY = cy - r + (r * 0.18).toNumber();
			if (y >= closeY && y <= closeY + btnH) {
				stopwatchActive = false;
				WatchUi.requestUpdate();
				return true;
			}

			// START / RESET button zone (bottom)
			var btnRowY = cy + r - (r * 0.18).toNumber() - btnH;
			if (y >= btnRowY && y <= btnRowY + btnH) {
				if (x < cx) {
					// START / STOP (left button)
					if (stopwatchRunning) {
						stopwatchElapsed = stopwatchElapsed + (System.getTimer() - stopwatchStartTime);
						stopwatchRunning = false;
					} else {
						stopwatchStartTime = System.getTimer();
						stopwatchRunning = true;
					}
				} else {
					// RESET (right button)
					stopwatchElapsed = 0;
					stopwatchLap = 0;
					stopwatchLapText = "";
					stopwatchRunning = false;
				}
			}

			WatchUi.requestUpdate();
			return true;
		}

		if (calculatorActive) {
			var cx = screenW / 2;
			var cy = screenH / 2;
			var r = (screenW * 0.45).toNumber();
			var inset = 4;
			var pad = 2;
			var innerPad = 3;
			var totalRows = 7;
			var totalH = 2 * r;
			var rowH = ((totalH - innerPad * (totalRows + 1)) / totalRows).toNumber();
			var circleTop = cy - r;
			var firstRowY = circleTop + innerPad;
			var calcButtons = ["7","8","9","/","4","5","6","x","1","2","3","-","C","0",".","+","="];

			// Determine which row was tapped
			var rowIdx = ((y - firstRowY) / (rowH + innerPad)).toNumber();
			if (rowIdx < 0) { rowIdx = 0; }
			if (rowIdx > 6) { rowIdx = 6; }

			// Row 0 = display, Row 1 = CLOSE
			if (rowIdx <= 1) {
				calculatorActive = false;
				WatchUi.requestUpdate();
				return true;
			}

			// Compute chord width at this row's center
			var yPos = firstRowY + rowIdx * (rowH + innerPad);
			var midY = yPos + rowH / 2;
			var dy = midY - cy;
			var dySq = dy * dy;
			var rSq = r * r;
			if (dySq >= rSq) { return true; }
			var halfW = Math.sqrt(rSq - dySq).toNumber() - inset;
			var rowStartX = cx - halfW;
			var rowW = halfW * 2;

			if (x < rowStartX || x > rowStartX + rowW) { return true; }

			var btnRow = rowIdx - 2;
			if (btnRow < 4) {
				var col = ((x - rowStartX) * 4 / rowW).toNumber();
				if (col < 0) { col = 0; }
				if (col > 3) { col = 3; }
				var btnIdx = btnRow * 4 + col;
				calcProcessButton(calcButtons[btnIdx]);
			} else {
				// Bottom row: = (left 3/4) and % (right 1/4)
				var eqW = ((rowW - pad) * 3 / 4).toNumber();
				if (x < rowStartX + eqW + pad) {
					calcProcessButton("=");
				} else {
					calcProcessButton("%");
				}
			}
			WatchUi.requestUpdate();
			return true;
		}

		// Normal watch face touch zones
		var _touch = false;
		try { _touch = Application.Properties.getValue("touchOn"); } catch (e) {}

		// Right side tap: open stopwatch
		if (_touch && x > screenW * 0.70 && y > screenH * 0.20 && y < screenH * 0.80) {
			stopwatchActive = true;
			WatchUi.requestUpdate();
			return true;
		}

		// Bottom tap: open calculator
		if (_touch && y > screenH * 0.70) {
			calculatorActive = true;
			calcDisplayText = "0";
			calcCurrentValue = 0.0;
			calcPendingOp = null;
			calcNewInput = true;
			calcHasDecimal = false;
			WatchUi.requestUpdate();
			return true;
		}
		return false;
	}

}

function calcProcessButton(label) {
	if (label.equals("C")) {
		calcDisplayText = "0";
		calcCurrentValue = 0.0;
		calcPendingOp = null;
		calcNewInput = true;
		calcHasDecimal = false;
		return;
	}

	if (label.equals("+") || label.equals("-") || label.equals("x") || label.equals("/")) {
		if (!calcNewInput) {
			calcDoCalculate();
		}
		calcCurrentValue = calcDisplayText.toFloat();
		calcPendingOp = label;
		calcNewInput = true;
		calcHasDecimal = false;
		return;
	}

	if (label.equals("=")) {
		calcDoCalculate();
		calcPendingOp = null;
		calcNewInput = true;
		calcHasDecimal = false;
		return;
	}

	if (label.equals("%")) {
		var val = calcDisplayText.toFloat();
		if (calcPendingOp != null && (calcPendingOp.equals("+") || calcPendingOp.equals("-"))) {
			val = calcCurrentValue * val / 100.0;
		} else {
			val = val / 100.0;
		}
		calcDisplayText = val.format("%.6f");
		while (calcDisplayText.length() > 1 && calcDisplayText.substring(calcDisplayText.length() - 1, calcDisplayText.length()).equals("0")) {
			calcDisplayText = calcDisplayText.substring(0, calcDisplayText.length() - 1);
		}
		if (calcDisplayText.substring(calcDisplayText.length() - 1, calcDisplayText.length()).equals(".")) {
			calcDisplayText = calcDisplayText.substring(0, calcDisplayText.length() - 1);
		}
		calcNewInput = false;
		return;
	}

	if (label.equals(".")) {
		if (calcHasDecimal) { return; }
		calcHasDecimal = true;
		if (calcNewInput) {
			calcDisplayText = "0.";
			calcNewInput = false;
		} else {
			calcDisplayText = calcDisplayText + ".";
		}
		return;
	}

	// Digit
	if (calcNewInput) {
		calcDisplayText = label;
		calcNewInput = false;
	} else {
		if (calcDisplayText.equals("0")) {
			calcDisplayText = label;
		} else {
			if (calcDisplayText.length() < 10) {
				calcDisplayText = calcDisplayText + label;
			}
		}
	}
}

function calcDoCalculate() {
	if (calcPendingOp == null) { return; }
	var b = calcDisplayText.toFloat();
	var result = calcCurrentValue;
	if (calcPendingOp.equals("+")) { result = calcCurrentValue + b; }
	else if (calcPendingOp.equals("-")) { result = calcCurrentValue - b; }
	else if (calcPendingOp.equals("x")) { result = calcCurrentValue * b; }
	else if (calcPendingOp.equals("/")) {
		if (b != 0) { result = calcCurrentValue / b; }
		else { calcDisplayText = "ERR"; calcCurrentValue = 0.0; return; }
	}
	calcCurrentValue = result;
	var absResult = result;
	if (absResult < 0) { absResult = -absResult; }
	if (result == 0.0) {
		calcDisplayText = "0";
	} else if (absResult >= 1000000000.0 || (absResult < 0.0001 && absResult > 0.0)) {
		// Scientific notation for very large or very small numbers
		// log10(x) = ln(x) / ln(10)
		var exp = Math.floor(Math.ln(absResult) / 2.302585).toNumber();
		// Compute 10^exp manually
		var divisor = 1.0;
		if (exp >= 0) {
			for (var i = 0; i < exp; i++) { divisor = divisor * 10.0; }
		} else {
			for (var i = 0; i < -exp; i++) { divisor = divisor / 10.0; }
		}
		var mantissa = result / divisor;
		var mStr = mantissa.format("%.2f");
		calcDisplayText = mStr + "e" + exp.toString();
	} else if (result == result.toNumber().toFloat()) {
		calcDisplayText = result.toNumber().toString();
	} else {
		calcDisplayText = result.format("%.4f");
		while (calcDisplayText.length() > 1 && calcDisplayText.substring(calcDisplayText.length() - 1, calcDisplayText.length()).equals("0")) {
			calcDisplayText = calcDisplayText.substring(0, calcDisplayText.length() - 1);
		}
	}
	if (calcDisplayText.length() > 12) {
		calcDisplayText = calcDisplayText.substring(0, 12);
	}
}

// SunCal class is now in suncal.mc (standalone file with polar latitude fix)
