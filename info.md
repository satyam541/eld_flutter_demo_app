Welcome to geometris Portal Skip to Content Skip to Menu Skip to Footer
Geometris Support
Home
Tickets
Knowledge Base
PA
English
Knowledge Base
Geometris
Packets

Packet Data

Info
An example packet looks like the following: 

F001,81A161260005,IGN_OFF,1492711944,29.85657,-95.64319,77,0,0,114,0,0,32376.1,7,,35198,10449,,,,32372.0T,1N4AL3AP3GN360245,,0:0,,,, 



This packet can be dissembled as follows:

Packet Item Number	Packet Item Name	Value
65	FORMAT CRC	F001
28	SERIAL NUMBER	81A161260005
9	REASON TEXT	IGN OFF
36	EVENT UNIX TIME	1492711944
3	LAT DEGREES	29.85657
4	LON DEGREES	-95.64319
7	UNIQUE ID	77
8	LOCATION AGE	0
11	IGNITION	0
12	DURATION	114
14	SPEED MPH	0
17	HEADING DEGREES	0
24	ODOMETER MILES	32376.1
50	NUM SATELLITES	7
56	FENCE ID	
51	IGNITION ON DUR	35198
55	TOTAL IDLE DUR	10449
70	ECU RPM	
71	ECU COOLANT TEMP	
72	ECU SPEED MILES	
73	ECU ODOMETER MILES	32372.0T
74	ECU VIN	1N4ALXAPXGN360245
75	ECU FUELLVL	
76	DTC	0:0
77	ECU THROTTLE	
80	ECU MPG	
81	OBD TRIP MPG	
82	OBD INSTANT MPG


The packet structure above reflects the default configuration for packet format


Info
SETPARAMS 12 =65.28.9.36.3.4.7.8.11.12.14.17.24.50.56.51.55.70.71.72.73.74.75.76.77.80.81.82;

Packet items can be removed or added by modifying parameter number 12

For example: Changing the parameter value to 65.28.9.36.3.4.7.8.11.12.14.17.24.50.56.51.55.70.71.72.73.74.75.76.77.80.81 will remove  Packet Item 82: OBD Instant MPG from all transmitted packets.





You can also download the following application to parse your Packet information. Input your current Configuration and Packet received to parse the packet.
Info
ATTACHMENT BELOW

Alert
If you're using a Geometris SIM, you can customize the configuration of Parameter 12 (Data Packet Assembly Format) to your liking, but it's important to note that the packet format must start with the sequence of numbers noted below for our servers to parse the data correctly:
65.28.9.36 - Reason Text
65.28.10.36 - Reason Code
Info
To query packet items please see the POLLQ command in Data Query Commands article



Packet Items



The following table lists all available packet items. Items numbers can be chained together, delimited by a ‘.’ And set in parameter 12 to define the desired packet structure. *See are clickable link, please click on the link for more information.

Source
The Source attribute has three potiencial values:
ECU: Indicating the packet originated from the Electronic Control Unit.
Device: Indicating the packet originated from the device.
Both: Indicating the packet has multiple origins, namely both the ECU and Device.

#	Item Name	Unit	Source	Description
1	ICCID	Alphanumeric	Device	SIM card unique serial number (ICCID)
2	EVENT UTC TIME	Seconds	Device	Number of seconds elapsed between Jan 1, 1970 and the event time.
3	LATITUDE DEGREES	Floating Point Number	Device	Latitude in degrees with 5 decimal places
4	LONGITUDE DEGREES	Floating Point Number	Device	Longitude in degrees with 5 decimal places
7	UNIQUE ID	Numeric	Device	Unique sequence number that recycles back to 0 when the whereQube resets
8	LOCATION AGE	Numeric	Device	Number of minutes since the last good fix was computed
9	REASON TEXT	Alphanumeric	Device	A textual reason why the event was generated
10	REASON CODE	Numeric	Device	A numeric reason why the event was generated
11	IGNITION	Numeric	Device	0 or 1 signifying the ignition state
12	DURATION	Minutes	Device	Context based duration value(e.g Idling event has been reporting for "reported duration")
13	SPEED KMH	KMH	Device	Speed in Kilometers per hour calculated by GPS
14	SPEED MPH	MPH	Device	Speed in Miles per Hour calculated by GPS
15	SPEED MPS	MPS	Device	Speed in Meters per Second calculated by GPS
16	HEADING ALPHA	Alphanumeric	Device	N,S,E,W translation of heading
17	HEADING DEGREES	Numeric	Device	Heading in degrees useful for calculating cardinal directions
18	ODOMETER DTC KM	Numeric	ECU	Odometer since DTC in KM
Once DTC is cleared, the odometer reading resets to zero, and subsequently begins to increment as the vehicle accumulates mileage.
19	ODOMETER DTC MILES	Miles	ECU	Odometer since DTC in Miles

Once DTC is cleared, the odometer reading resets to zero, and subsequently begins to increment as the vehicle accumulates mileage.
20	ROLL TIME	Seconds	Device	Total time equipment has been in motion
21	TRUE ODOMETER KM	KM	ECU	Actual vehicle odometer, else empty
22	TRUE ODOMETER MILES	Miles	ECU	Actual vehicle odometer, else empty
23	ODOMETER KM	KM	Device	Odometer in Kilometers
24	ODOMETER MILES	Miles	Device	Odometer in Miles
25	HIGHEST GPS SPEED MPH	MPH	Device	Firmware above Q1 2024: Highest GPS Speed is retained while SPEEDING and cleared after being included in the SPEEDING END message.
26	TRIP ID	Numeric	Device	All packets related to the trip are linked by this common Trip ID. It currently uses the timestamp from the start of the trip, making it unique.
27	IMEI	Numeric	Devices	Device IMEI in 15 Digit
28	SERIAL NUMBER	Alphanumeric	Device	Unique Serial Number for each whereQube
29	EVENT DISTANCE	Numeric	Device	Distance covered during a specific event, measured in 1/1000th of a mile. The EVENT DISTANCE field is context-based, meaning SPEEDING END will contain the distance traveled during that specific speeding event.
30	ANALOG SIGNAL VOLTAGE	Numeric	Device	External Analog Signal Voltage recced by the device, used exclusively with the 68W/79V Series. Values in millivolts (mV).
32	BAND	String	Device	Channel band used for LTE wireless communication
33	ACCELEROMETER TRIGGER MAGNITUDE	Numeric	Device	Only available if this packet is generated by an accelerometer event
34	ACCELEROMETER DURATION	Numeric	Device	Only available if this packet is generated by an accelerometer event
35	PHONE NUMBER	Alphanumeric	Device	Phone number of modem if available
36	EVENT UNIX TIME	Seconds	Device	Unique time stamp
37	ACCELEROMETER POINT	String	Device	Instantaneous X/Y/Z accelerometer data
38	ACCELEROMETER SNAPSHOT	String	Device	In this packet item, the device provides accelerometer data configurable for the duration of the event combined into a single packet.
39	LOCATION TRAIL	*See GPS Trails	Device	Trails provide a high-resolution travel path for vehicles, allowing for bread crumb trails of vehicle location & speed.
40	IOSTATES	Numeric	Device	Bitfield to reflect actual state of IO. Bitwise-AND the data to determine individual state. 0x100 for Ignition wire, 0x200 for panic button input
41	ACCELSPEEDS	Numeric	Device	Speed values (in mph) around acceleration events such as HARDSTOP, HARDBRAKE, HARDTURN, HARDACCEL. Format: Initial Speed : Final Speed. (Retired RMC which was used in 3G)
42	IGNITION STRING	Alphanumeric	Device	Ignition state as a string. ON or OFF
43	BLE CLIENT STATE	Numeric	Device	Bluetooth connected state. 1=connected, 0=disconnected, empty = unknown
44	EVENT TIME STRING	Alphanumeric	Device	String representation of time. Uses strftime C runtime function. Default format is "%m/%d/%Y%H:%M:%S". Can be configured to a different format if needed in CFG TIME FMT config item (140).
45	BLE CLIENT INFORMATION	String	Device	BLEState:BLEClient:SecondElapsed:ClientAddressType:ClientMACAdress
Example: 2:1:5379:FF:507443A2ED27
46	LOCATION HDOP	Numeric	Device	HDOP value used in location fix
47	SESSION IDLE DURATION	Numeric	Both	Current session idling time in minutes
48	PACKET COUNT	Numeric	Device	Number of packets in queue (count is prior to the current packet being assembled)
49	SATELLITES IN VIEW	Numeric	Device	Number of satellites in view
50	SATELLITES	Numeric	Device	Number of satellites used in fix
51	IGNITION DURATION	Seconds	Device	Cumulative seconds Ignition was on
52	WANT ACK	Character Y/N	Device	Request acknowledgements from Server flag
53	BATTERY VOLTAGE	Millivolts	Device	Battery voltage measured in mv measured by device
54	INTERNAL BATTERY VOLTAGE	Millivolts	Device	Battery voltage measured in mv of the internal battery in Device
55	TOTAL IDLE DURATION	Seconds	Both	Total Duration of time that the vehicle has been in idling state
56	FENCE ID	Numeric	Device	Shows active fence ID
57	ALTITUDE	Meters	Device	Shows Altitude in meters
59	TEMPERATURE	Numeric	Device	Current device temperature in Celsius. Empty if currently unavailable.
60	CRC	Hexadecimal 4-byte	Device	16 bit CCITT Checksum of packet contents
61	ODOMETER CHANGE (KM)	KM	Both	Change in odometer since last packet construction (in km). ECU if gps odometer is overwrite by ECU odometer
62	ODOMETER CHANGE (MILES)	Miles	Both	Change in odometer since last packet construction (in miles). ECU if gps odometer is overwrite by ECU odometer
63	CELL INFORMATION	MNC:MCC:LAC:CellID:TA	Device	Cellular Information - More Information here
64	JAMMING LEVEL	Numeric	Device	*RESERVED FOR FUTURE USE
65	FORMAT CHECKSUM	Hexadecimal 4-byte	Device	16 bit CCITT Checksum of packet format string (Useful to switch server parser based on packet contents).
66	FIRMWARE VERSION	Hexadecimal 4-byte:Numeric:Numeric	Device	16 bit CCITT Checksum of App Firmware version string:Supervisor FW Version:Bluetooth FW Version (Bluetooth FW Version only present on devices that support Bluetooth).
67	CONFIG VERSION	Hexadecimal 4-byte:Numeric:Numeric	Device	16 bit CCITT Checksum of App Firmware default config settings:16 bit CCITT Checksum of App Firmware modified config settings
68	CELL RSSI	Numeric	Device	Current Cell RSSI value
69	CLUSTER DATA	*See Location Clusters Section	Device	Location Cluster Data
70	ENGINE RPM	Numeric	ECU	Instantaneous engine RPM
71	ENGINE COOLANT TEMPERATURE	Celsius	ECU	Instantaneous engine coolant temperature
72	ENGINE SPEED	MPH	ECU	Instantaneous speed reported by ECU in MPH
73	ENGINE ODOMETER	Miles	ECU	Odometer reported by ECU in miles
74	VEHICLE IDENTIFICATION NUMBER	Alphanumeric	Both	VIN number reported by ECU. Can also be set by using SETVIN command
75	FUEL LEVEL	Numeric - Percentage	ECU	Fuel level reported by ECU (1-100%)
76	ECU ACTIVE DTC	*See DTC Codes	ECU	Active Diagnostic Trouble Codes reported by ECU
77	THROTTLE POSITION	Numeric - Percentage	ECU	Throttle Position reported by ECU
78	BATTERY VOLTAGE	Millivolts	ECU	Battery Voltage reported by ECU
79	AMBIENT TEMPERATURE	Celsius	ECU	Ambient Temperature reported by ECU
80	CUMULATIVE FUEL ECONOMY	Miles Per Gallon X 100	Both	Cumulative Fuel Economy calculated for vehicle, in hundreds of miles per gallon.
81	TRIP FUEL ECONOMY	Miles Per Gallon X 100	Both	Fuel Economy calculated for current trip, in hundreds of miles per gallon.
82	CURRENT FUEL ECONOMY	Miles Per Gallon X 100	Both	Instantaneous Fuel Economy calculated, in hundredths of miles per gallon.
83	ECU RPM BANDS	*See RPM BANDS Section	ECU	RPM Bands refer to ranges of engine RPM at different times
84	SPEED BANDS	*See SPEED BANDS Section	ECU	Speed Bands refer to ranges of engine speeds at different times. Source is best available speed(GPS or ECU)
87	DISCOVERY	*See Vehicle Data Discovery	ECU	Vehicle capabilities in hex
89	ECU ALL DTC	* See DTC Codes Section	ECU	All Diagnostic Trouble Codes reported by ECU
90	DPFREGEN INHIBIT	Numeric	ECU	0=Not inhibited, 01=Inhibited
91	ECU ENGINE HOURS	Numeric	ECU	In 1/100th hour increments, eg, 76168 is 761.68 Hours.
92	TOTAL FUEL USED	Numeric - Deciliters	Both	Total fuel used for petrol or diesel engines. Captured from ECU (J1939/J1708) or OBD-II when available; if not, then uses calculated values.
93	ECU TOTAL GAS USED	Numeric - Hectograms	ECU	Total gas used for gaseous engines (e.g., natural gas)
94	ECU IDLE HOURS (TOTAL)	Numeric	ECU	In 1/100th hour increments e.g 27155 = 271.55 Hours
95	ECU TOTAL PTO HOURS	Numeric	ECU	In 1/100th hour increments, eg, seconds / 36
96	MAX VEHICLE SPEED LIMIT	Numeric - Km/h	ECU	Speed limit set in ECU
97	ECU OIL TEMPERATURE	Numeric 1/100th degree Celsius	ECU	In hundredths of degrees Celsius
98	ECU ENGINE OIL LEVEL	Numeric - 1/10 Percentage	ECU	Oil level reported by ECU. e.g 1000/10= 100%
99	ECU COOLANT LEVEL	Numeric - 1/10 Percentage	ECU	Coolant level reported by ECU. e.g 1000/10= 100%
100	ECU DIESEL EXHAUST FLUID LEVEL	Numeric - 1/10
Percentage	ECU	DEF level reported by ECU e.g 712 = 71.2 %
101	ECU DIESEL EXHAUST FLUID TEMPERATURE	Numeric - Celsius	ECU	DEF temperature reported by ECU
102	DPF SOOT LOAD	Numeric - Percentage	ECU	Soot DPF Buildup reported by ECU (0-250%) with 100% triggering active regeneration, and 0%, 25%, 50%, and 75% representing varying soot levels before regeneration is needed
103	DPF TIME SINCE LAST ACTIVE REGENERATION	Numeric-Seconds	ECU	Value can be between 0-421,108,1215 seconds
104	DPF SOOT LOAD REGENERATION THRESHOLD	Numeric-1/10000 Percentage	ECU	0-160.6375 % e.g 555300 = 55.53%
105	DPF STATUS	Numeric	ECU	000 = Regeneration not needed, 001 = Regeneration needed - lowest level, 010 = Regeneration needed - moderate level, 011 = Regeneration needed - highest level, 7= Not available
106	DPF ACTIVE REGENERATION STATUS	Numeric	ECU	00=not active,01=active,10=regeneration needed(Automatically initiated active regeneration imminent),11=not available
107	TRANSMISSION OIL LEVEL	Numeric-Percentage	ECU	Oil level reported by ECU
108	TRANSMISSION OIL TEMPERATURE	Numeric- 1/100
Celsius	ECU	Oil temperature reported by ECU ( Range: -273 to 1735 ) e.g 6346 = 63.46 Celsius
109	TRANSMISSION CURRENT GEAR	Numeric	ECU	Values from -125 to +125 represent gears: negative for reverse, positive for forward, zero for neutral, and 126 for park.
110	SEATBELT SWITCH	Numeric	ECU	State of switch used to determine if Seat Belt is buckled. (0) NOT Buckled. (1) OK - Seat Belt is buckled. (2) Error - Switch state cannot be determined. (3) & (255) Not Available
111	ECU ODOMETER KM	KM	ECU	Odometer reported by ECU in kilometers
112	ECU SPEED KM	KPH	ECU	Instantaneous speed reported by ECU in KPH
113	ECU CRUISE CONTROL STATE TIME	Numeric-Seconds	ECU	Total time cruise control is engaged in seconds. Reset after each use in packet
114	ECU CRUISE CONTROL STATE	Numeric	ECU	1=Hold,2=Accelerate,3=Decelerate,4=Resume,5=Set,6=Override
115	DM1	* See DTC Codes Section	ECU	Diagnostic Trouble Codes reported by ECU for J1939 Protocol
116	DM2	* See DTC Codes Section	ECU	Diagnostic Trouble Codes reported by ECU for J1939 Protocol
117	BEACON DATA	Numeric	Device	Beacon Data
118	IDLE FUEL USED	Numeric - Deciliters	Both	Fuel used while idling for petrol or diesel engines. Captured from ECU for J1939/J1708; calculated for OBD-II.(Tracker Tenure)
119	TRIP FUEL USED	Numeric - Deciliters	Both	Trip fuel used for petrol or diesel engines. Captured from ECU for J1939/J1708; calculated for OBD-II.
120	ECU TRIP GAS USED	Numeric - Hectograms	ECU	Trip gas used for gaseous engines (e.g., natural gas)
121	TPMS ALL TIRES	* See Configuring TPMS Section	ECU	Add all tires information to the packet
122	TPMS FAULT TIRES	* See Configuring TPMS Section	ECU	Add only faulty tires information to the packet
123	PTO STATE	Numeric	Both	PTO Governor State. 0=off, 1 through 19 engaged. Can also be hardwired to generate PTO State
124	ECU CHARGELVL	Numeric-Percentage	ECU	Electric vehicle Charge level.
125	OIL LIFE	Numeric-Percentage	ECU	Remaining useful life of the engine oil
126	PRNDL POS	Numeric	ECU	0 = Park (P), 1 = Reverse (R), 2 = Neutral (N), 3 = Drive (D), 4 = Low/Sport/Manual (L)
127	PHEV DATA	*See Phev Data section	ECU	PHEV System Data
129	SESSION IGN DURATION	Numeric	Device	Time rolling since ignition was on (in minutes)
130	SESSION ROLL DURATION	Numeric	Device	Time rolling since continuously moving (in minutes)
131	ECU ODOMETERS	*See All Odometers	ECU	ALL_ODOMETERS from ECU only works on J1939
132	EV DATA	*See EV_DATA	ECU	Charging Data - {Charging (1 or 0)}:{Charger Type}:{Charge Level in %}:{Watt hours remaining}
133	SESSION SPEEDING DURATION	Numeric	Device	Time speeding continuously (in minutes)
134	PREVIOUS VIN	String	ECU	Previously stored VIN information
136	WAKE REASON	Bitmask	Device	Reason for device wake-up: Hard Wire Ignition, Soft Ignition, Motion, Panic Button Input, etc.
Bitfield for wakeup reason. One or more can be present at a time:
IGNITION: If Value & 0x01 - Hard Wire Ignition input
SIGNITION: If Value & 0x02 - Soft Ignition algorithm
MOTION: If Value & 0x04 - Motion
BUTTON: If Value & 0x08 - Panic Button Input
EXT APPLIED: If Value & 0x10 - External Power Applied
EXT REMOVAL: If Value & 0x20 - External Power Removed
TIMER: If Value & 0x40 - Timer-based wakeup
BUTTON AH: If Value & 0x100 - Panic Button Active High Input
137	IGNITION ON DURATION DIFFERENCE	Numeric	Device	Difference in ignition time since the previous packet. Measured in seconds
190	ONE-WIRE TEMPERATURE SENSOR SERIAL NUMBER	Alphanumeric	Peripheral	Serial number of One-wire temperature sensor (79/68W series only)
191	ONE-WIRE SENSOR TEMPERATURE	Numeric	Peripheral	Tenth of a Degree Celsius (79/68W series only)
192	ONE-WIRE/BLE DRIVER ID	String	Device	1-wire DRIVER ID tag information or BLE Driver ID tag information.
Multiple tags are separated by the space character
See for One-Wire Driver ID
See for BLE Driver ID
194	TOOL TAG	String	Device	Tool Tracking Tag information. Multiple tags are separated by the space character
200	RFG RAW	Alphanumeric	Peripheral	Raw packet data collected from Refrigeration unitVariable length field, encoded in hex
LEN DATA LEN DATA....
201	RFG ZONES	Numeric	Peripheral	Refrigeration Zone Data[Z:[ABCDEF]:G:H:I:J:K]
Z = Zone Index (1, 2, 3, or higher)
ABCDEF = Optional. Present if operating mode information is valid
A = Door State (0=closed, 1=open)
B = Electric/Diesel Mode (0=diesel, 1=electric)
C = Continuous. Only valid if diesel mode in effect (0=continuous mode, 1= cycling mode)
D = High Speed. Only valid if diesel mode in effect (0=normal speed, 1=high speed)
E = Operating State. (0=Power off/Unknown, 1=Cooling,2=Heating,3=Defrost,4=NULL,5=Pre-Trip,6=Sleep,7=Reserved
F = Fresh Air Door State (0=closed, 1=open)
G = Zone Error Code
H = Setpoint in tenth/celsius, X if out of range, empty sub-field if missing
I = Return Air Temperature in tenth/celsius, X if out of range, empty sub-field if missing
J = Supply Discharge Temperature in tenth/celsius, X if out of range, empty sub-field if missing
K = Evaporator Coil Temperature in tenth/celsius, X if out of range, empty sub-field if missing
202	RFG ACTIVE ALARM	Alphanumeric	Peripheral	(same as Field 203 for now. Future versions might separate codes by severity)
203	RFG ALL ALARM	Numeric	Peripheral	A:[B:C:D E:F G:H...]A = Malfunction Level. 1 = High Severity Malfunction Detected, 0 = High Severity Malfunction Not Detected
B = Number of Alarms
CD..EF..GH Separated by space character
C=Level
D=Value
204	RFG FUEL LEVEL	%	Peripheral	Fuel Level in Percentage. Empty field if unsupported. X if out of range.
205	RFG VOLTAGE	1/100 Volts	Peripheral	Refrigeration Trailer Battery Voltage in 1/100 Volts. Empty field if unsupported. X if out of range.
206	RFG AMB TEMP	10/Celsius	Peripheral	Ambient temperature in tenth/celsius, X if out of range, empty field if missing
207	RFG ELECTRIC HOURS	1/100 Hour	Peripheral	Electric Mode Hours in 1/100 hour. Empty field if unsupported.
208	RFG VEHICLE HOURS	1/100 Hour	Peripheral	Refrigeration Unit Vehicle Hours in 1/100 hour. Empty field if unsupported.
209	RFG ENGINE HOURS	1/100 Hour	Peripheral	Refrigeration Unit Engine Hours in 1/100 hour. Empty field if unsupported.
210	RFG ID	Alphanumeric	Peripheral	A:B:CA= Variable Length Serial Number, Empty sub-field if unsupported.
B = Variable Length Make, Empty sub-field if unsupported.
C = Variable Length Model, Empty sub-field if unsupported.
211	RFG SOFTID	Alphanumeric	Peripheral	Variable Length Software ID. Empty field if unsupported
212	RFG SW	Alphanumeric	Peripheral	Remote Switch State, [A:B:C:D:E], empty field if no switches supportedA = Switch 1, X if out of range, empty sub-field if unsupported
B = Switch 2, X if out of range, empty sub-field if unsupported
C = Switch 3, X if out of range, empty sub-field if unsupported
D = Switch 4, X if out of range, empty sub-field if unsupported
E = Switch 5, X if out of range, empty sub-field if unsupported
223	RFID STATE	String	Peripheral	UART1:Cnt:Rx:Act

1:1:6:13580

UART1 = UART Number = 1
Cnt = Card Read Count = 1
Rx = Receiving RFID Byte Count = 6
Act = RFID Activity Timestamp = 13580
225	TIMEZONE	Integer	Device	Time zone difference, expressed in quarters of an hour, between local time and GMT
Range: -48 to +48, Example: -28 = West Coast
226	CURRENT STATE	Numeric	Device	Indicates the state of the vehicle:
Off = 0, Idling = 1, On and Moving = 2, On and Speeding = 3, Off and Moving = 4, On and Not Moving = 5
227	TRIP DISTANCE	Numeric	Device	Distance traveled during the trip, measured in 1/1000th mile increments
Can be queried during or at the end of the trip
228	TRIP SPEEDING DISTANCE	Numeric	Device	Distance traveled while speeding, measured in 1/1000th mile increments
Can be queried during or at the end of the trip
229	TRIP AVERAGE SPEED	Numeric	Device	Average speed value during the trip, calculated as a sum of sampled speeds divided by the total number of samples
Only non-zero speeds are averaged
230	TRIP TIME	Numeric	Device	Total time during the trip, measured in seconds
Can be queried during or at the end of the trip
231	TRIP IDLE TIME	Numeric	Device	Total idle time during the trip, measured in seconds
Can be queried during or at the end of the trip
232	TRIP SPEEDING TIME	Numeric	Device	Total speeding time during the trip, measured in seconds
Can be queried during or at the end of the trip
233	TRIP ACCEL COUNTS	Numeric	Device	Counts of various acceleration events: Hard Acceleration, Hard Brake, Hard Turn, Hard Stop, Shock Count
Format: 5 subfields separated by :
234	TRIP SPEEDING COUNTS	Numeric	Device	Counts the number of times the speeding threshold is crossed during the configured duration
235	TRIP FUEL USED	Numeric	Device	Fuel used during the trip, measured in liters
Subtracting Packet Item Total Fuel Used (92) from Ignition On to Off.
236	TRIP CALC FUEL USED	Numeric	Device	Not actual vehicle provided fuel usage data. Calculated fuel data
237	TRIP FUEL LEVEL	Numeric	Device	ECU Fuel percentage used per Trip
238	TRIP ROLL TIME	Numeric	Device	Total roll time during the trip, measured in seconds
TRIP ROLL TIME can be used to distinguish between idling and moving time.
250	ECU FUELLVL DIFF	Percent	Device	Difference in fuel level (in percent) during ECU Fuel events
Used in FUELLOSS and REFUEL events only
Attachments :

PacketParserInstall.zip
13 MB
Updated: 3 months ago
On this page
To query packet items please see the POLLQ command in Data Query Commands article
Packet Items
Follow
Subscribe to receive notifications from this article.
Stats
1Follower
Packets
Packet Data
How to use Packet Parser
GPS Trails
Location Age(Packet Item 8) in Packet Data
Format Checksum
IOSTATES
FAQ for Packet Information
All Odometers
PTO Governor State
Electric Vehicles (EVs) Charging Data: Understanding Packet Item 132 (EV_DATA) and Charging Events
View all
Still can't find an answer?
Send us a ticket and we will get back to you.
Email: support@geometris.com
Phone: +1 (281) 856-9600 Ext: 2
Address: 10010 Houston Oaks Dr, Houston, TX 77064
Submit a ticket
AG