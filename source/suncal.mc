using Toybox.Math;

// SUNRISE AND SUNSET CLASS
class SunCal 
{
	// Lat North=+; South=-; Lon East=+; West=-;
	var latitude;
	var longitude;
	var julianDate;
	var m_year;
	var m_month;
	var m_day;
	var tzOffset; // positive  east, negative  west

	function SunSet(lat,lon,tz)
	{
	latitude = lat;
	longitude = -lon;
	julianDate = 0.0;
	tzOffset = tz;
	}

	function setPosition(lat,lon,tz)  // lat north is positive & lon east is positive
	{
		latitude = lat;
		longitude = -lon;
		tzOffset = tz;
	}

	function degToRad(angleDeg)
	{
	return (Math.PI * angleDeg / 180.0);
	}

	function radToDeg(angleRad)
	{
	return (180.0 * angleRad / Math.PI);
	}

	function calcMeanObliquityOfEcliptic(t)
	{
	var seconds = 21.448 - t*(46.8150 + t*(0.00059 - t*(0.001813)));
	var e0 = 23.0 + (26.0 + (seconds/60.0))/60.0;
	return e0;              // in degrees
	}

	function calcGeomMeanLongSun(t)
	{
	var L = 280.46646 + t * (36000.76983 + 0.0003032 * t);
	while ( L > 360) {   //  while ((int) L > 360) {
		L -= 360.0;
	}
	while (L <  0) {
		L += 360.0;
	}
	return L;              // in degrees
	}

	function calcObliquityCorrection(t)
	{
	var e0 = calcMeanObliquityOfEcliptic(t);
	var omega = 125.04 - 1934.136 * t;
	var e = e0 + 0.00256 * Math.cos(degToRad(omega));
	return e;               // in degrees
	}

	function calcEccentricityEarthOrbit(t)
	{
	return (0.016708634 - t * (0.000042037 + 0.0000001267 * t));
	//return e;               // unitless
	}

	function calcGeomMeanAnomalySun(t)
	{
	return (357.52911 + t * (35999.05029 - 0.0001537 * t));
	//return M;               // in degrees
	}
	function calcEquationOfTime(t)
	{
	var epsilon = calcObliquityCorrection(t);
	var l0 = calcGeomMeanLongSun(t);
	var e = calcEccentricityEarthOrbit(t);
	var m = calcGeomMeanAnomalySun(t);
	var y = Math.tan(degToRad(epsilon)/2.0);

	y *= y;

	var sin2l0 = Math.sin(2.0 * degToRad(l0));
	var sinm   = Math.sin(degToRad(m));
	var cos2l0 = Math.cos(2.0 * degToRad(l0));
	var sin4l0 = Math.sin(4.0 * degToRad(l0));
	var sin2m  = Math.sin(2.0 * degToRad(m));
	var Etime = y * sin2l0 - 2.0 * e * sinm + 4.0 * e * y * sinm * cos2l0 - 0.5 * y * y * sin4l0 - 1.25 * e * e * sin2m;
	return radToDeg(Etime)*4.0;	// in minutes of time
	}

	function calcTimeJulianCent(jd)
	{
	return (( jd - 2451545.0)/36525.0);
	//return T;
	}

	function calcSunTrueLong(t)
	{
	var l0 = calcGeomMeanLongSun(t);
	var c = calcSunEqOfCenter(t);
	var O = l0 + c;
	return O;               // in degrees
	}

	function calcSunApparentLong(t)
	{
	var o = calcSunTrueLong(t);
	var omega = 125.04 - 1934.136 * t;
	var lambda = o - 0.00569 - 0.00478 * Math.sin(degToRad(omega));
	return lambda;          // in degrees
	}

	function calcSunDeclination(t)
	{
	var e = calcObliquityCorrection(t);
	var lambda = calcSunApparentLong(t);
	var sint = Math.sin(degToRad(e)) * Math.sin(degToRad(lambda));
	var theta = radToDeg(Math.asin(sint));
	return theta;           // in degrees
	}

	function calcHourAngleSunrise(lat, solarDec)
	{
	var latRad = degToRad(lat);
	var sdRad  = degToRad(solarDec);
	// Guard against division by zero at exactly ±90° latitude
	var cosLat = Math.cos(latRad);
	var cosDec = Math.cos(sdRad);
	if (cosLat == 0 || cosDec == 0) { return 0; }
	// 30 Jan 2026: Calculate the cosine of the hour angle
	// At polar latitudes (above ~66°) during midnight sun or polar night,
	// this value can exceed the valid range [-1, 1] for Math.acos(),
	// which would return NaN and crash the watch face.
	var cosHA = Math.cos(degToRad(90.833))/(cosLat*cosDec)-Math.tan(latRad) * Math.tan(sdRad);
	// Clamp cosHA to [-1, 1] to prevent NaN from Math.acos()
	// Values outside this range indicate no sunrise (polar night) or no sunset (midnight sun)
	if (cosHA < -1) { cosHA = -1; }
	if (cosHA > 1) { cosHA = 1; }
	var HA = Math.acos(cosHA);
	return HA;              // in radians
	}

	function calcHourAngleSunset(lat, solarDec)
	{
	var latRad = degToRad(lat);
	var sdRad  = degToRad(solarDec);
	// Guard against division by zero at exactly ±90° latitude
	var cosLat = Math.cos(latRad);
	var cosDec = Math.cos(sdRad);
	if (cosLat == 0 || cosDec == 0) { return 0; }
	// 30 Jan 2026: Calculate the cosine of the hour angle
	// At polar latitudes (above ~66°) during midnight sun or polar night,
	// this value can exceed the valid range [-1, 1] for Math.acos(),
	// which would return NaN and crash the watch face.
	var cosHA = Math.cos(degToRad(90.833))/(cosLat*cosDec)-Math.tan(latRad) * Math.tan(sdRad);
	// Clamp cosHA to [-1, 1] to prevent NaN from Math.acos()
	// Values outside this range indicate no sunrise (polar night) or no sunset (midnight sun)
	if (cosHA < -1) { cosHA = -1; }
	if (cosHA > 1) { cosHA = 1; }
	var HA = Math.acos(cosHA);
	return -HA;              // in radians
	}

	function calcJD(y, m, d)
	{
	if (m <= 2) {
		y -= 1;
		m += 12;
	}
	var A = Math.floor(y/100);
	var B = 2 - A + Math.floor(A/4);
	var JD = Math.floor(365.25*(y + 4716)) + Math.floor(30.6001*(m+1)) + d + B - 1524.5;
	return JD;
	}

	function calcJDFromJulianCent(t)
	{
	return (t * 36525.0 + 2451545.0);
	//return JD;
	}

	function calcSunEqOfCenter(t)
	{
	var m = calcGeomMeanAnomalySun(t);
	var mrad = degToRad(m);
	var sinm = Math.sin(mrad);
	var sin2m = Math.sin(mrad+mrad);
	var sin3m = Math.sin(mrad+mrad+mrad);
	var C = sinm * (1.914602 - t * (0.004817 + 0.000014 * t)) + sin2m * (0.019993 - 0.000101 * t) + sin3m * 0.000289;
	return C;		// in degrees
	}

	function calcSunrise()
	{
	var t = calcTimeJulianCent(julianDate);
	// *** First pass to approximate sunrise
	var eqTime = calcEquationOfTime(t);
	var solarDec = calcSunDeclination(t);
	var hourAngle = calcHourAngleSunrise(latitude, solarDec);
	var delta = longitude - radToDeg(hourAngle);
	var timeDiff = 4 * delta;	// in minutes of time
	var timeUTC = 720 + timeDiff - eqTime;	// in minutes
	var newt = calcTimeJulianCent(calcJDFromJulianCent(t) + timeUTC/1440.0);

	eqTime = calcEquationOfTime(newt);
	solarDec = calcSunDeclination(newt);
	hourAngle = calcHourAngleSunrise(latitude, solarDec);
	delta = longitude - radToDeg(hourAngle);
	timeDiff = 4 * delta;
	timeUTC = 720 + timeDiff - eqTime; // in minutes
	var localTime = timeUTC + (60 * tzOffset);
	if (localTime>1440) {localTime=localTime-1440;} // if the result is greater than 24 hours subtract 24 hours
	if (localTime<0) {localTime=localTime+1440;} // if the result is negative add 24 hours
	return localTime;	// return time in minutes from midnight
	}

	function calcSunriseTomorrow()
	{
	var t = calcTimeJulianCent(julianDate+1);
	// *** First pass to approximate sunrise
	var eqTime = calcEquationOfTime(t);
	var solarDec = calcSunDeclination(t);
	var hourAngle = calcHourAngleSunrise(latitude, solarDec);
	var delta = longitude - radToDeg(hourAngle);
	var timeDiff = 4 * delta;	// in minutes of time
	var timeUTC = 720 + timeDiff - eqTime;	// in minutes
	var newt = calcTimeJulianCent(calcJDFromJulianCent(t) + timeUTC/1440.0);

	eqTime = calcEquationOfTime(newt);
	solarDec = calcSunDeclination(newt);
	hourAngle = calcHourAngleSunrise(latitude, solarDec);
	delta = longitude - radToDeg(hourAngle);
	timeDiff = 4 * delta;
	timeUTC = 720 + timeDiff - eqTime; // in minutes
	var localTime = timeUTC + (60 * tzOffset);
	if (localTime>1440) {localTime=localTime-1440;} // if the result is greater than 24 hours subtract 24 hours
	if (localTime<0) {localTime=localTime+1440;} // if the result is negative add 24 hours
	return localTime;	// return time in minutes from midnight
	}

	function calcSunset()
	{
	var t = calcTimeJulianCent(julianDate);
	// *** First pass to approximate sunset
	var eqTime = calcEquationOfTime(t);
	var solarDec = calcSunDeclination(t);
	var hourAngle = calcHourAngleSunset(latitude, solarDec);
	var delta = longitude - radToDeg(hourAngle);
	var timeDiff = 4 * delta;	// in minutes of time
	var timeUTC = 720 + timeDiff - eqTime;	// in minutes
	var newt = calcTimeJulianCent(calcJDFromJulianCent(t) + timeUTC/1440.0);

	eqTime = calcEquationOfTime(newt);
	solarDec = calcSunDeclination(newt);
	hourAngle = calcHourAngleSunset(latitude, solarDec);
	delta = longitude - radToDeg(hourAngle);
	timeDiff = 4 * delta;
	timeUTC = 720 + timeDiff - eqTime; // in minutes
	var localTime = timeUTC + (60 * tzOffset);
	if (localTime>1440) {localTime=localTime-1440;} // if the result is greater than 24 hours subtract 24 hours
	if (localTime<0) {localTime=localTime+1440;} // if the result is negative add 24 hours
	return localTime;	// return time in minutes from midnight
	}

	function setCurrentDate(y, m, d)
	{
	m_year = y;
	m_month = m;
	m_day = d;
	julianDate = calcJD(y, m, d);
	return julianDate;
	}
}