#This code serves as an interface between the thingsboard.io based user interface and the xbee based turbine network. This version was written specifically for the user interface that has individual on/off switches for each turbine.

import serial #for connecting to local xbee through serial port
from digi.xbee.devices import XBeeDevice, RemoteXBeeDevice, XBee64BitAddress #for interacting with xbee network
from digi.xbee.io import IOLine, IOMode, IOValue #for processing DIO data from the xbee network
import paho.mqtt.client as mqtt #for interacting with thingsboard.io through mqtt messaging protocol
import json #makes converting between json libraries and strings easier. This helps processing mqtt messages.
import time 
import threading #is this still needed?
import csv #Allows us to read in comma seperated value (csv) data files. Used to read inputFile.txt
from random import *
standardOutput = 'gateway.out'

###################################################################################
### Part 0: User specified parameters
###################################################################################
localXBeePort = '###########' #this is the USB port that the XBee is plugged into.

faultMap = {
	IOLine.DIO2_AD2:'vibration_fault', 
	IOLine.DIO3_AD3:'low_pressure_fault', 
	IOLine.DIO6:'overspeed_fault', 
	IOLine.DIO10_PWM0:'wind_speed_fault'}  

###################################################################################
### Part 1: MQTT stuff
###################################################################################
mqttClientId     = "#########" #This can be anything, but you have to pick a unique Id so thingsboard can keep track of what messages it has already sent you.
mqttBroker = "127.0.0.1" #This is the local host instance of thingsboard.
mqttUserName     = "###############" #this is the access token for the thingsboard gateway device # put this in an input file

topicAttr = "v1/gateway/attributes" #This is the topic for sending attributes through a gateway in thingsboard  
topicTelem = "v1/gateway/telemetry" #This is the topic for sending telemetry through a gateway in thingsboard  
topicConnect = "v1/gateway/connect"

# The callback for when we recieve a CONNACK response from the MQTT server.
def on_connect(MQTT, userdata, flags, rc):
    print("Connected with result code "+str(rc), file=open(standardOutput, 'a')) #result code 0 means sucessfuly connected
    MQTT.subscribe("v1/gateway/rpc") #Subscribing to receive RPC requests

# The callback when we receive a message from the MQTT server.
def on_message(client, userdata, msg):
	global MQTT_message, new_MQTT_message
	print('Topic: '+str(msg.topic)+'\nMessage: '+str(msg.payload), file=open(standardOutput, 'a'))
	MQTT_message = msg
	new_MQTT_message = True 
	
#This reads the turbine parameter input file inputFile.txt and formats the data in the necessary libraries that will be used by other parts of this program.
def readTurbineInputFile(): 
	addr2name = {}
	name2addr = {}
	lastMessageTime = {}
	genData = {}
	with open('inputFile.txt') as f : #read input file and store data in the list turbArrayProps
		reader = csv.reader(f, delimiter="\t")
		turbArrayProps = list(reader)
	for i in range(1, len(turbArrayProps)): #process each row in input file
		print("i = "+str(i), file=open(standardOutput, 'a'))
		name = turbArrayProps[i][0]
		address = '0013A200'+turbArrayProps[i][1]
		address = address.upper() #convert address to upper case if it isn't already.
		latitude = turbArrayProps[i][2]
		longitude = turbArrayProps[i][3]
		addr2name[address] = name #to find a turbine name from the remote XBee address
		name2addr[name] = address #The reverse of the previous dictionary. Used to find the remote XBee address from a turbine name
		lastMessageTime[name] = time.time() #current time expressed in seconds since epoch
		MQTT.publish(topicConnect, json.dumps({'device':name})) #Tell thingsboard that this turbine is connected. These turbines will be visible on the Wind Plant Controller dashboard.
		MQTT.publish(topicConnect, json.dumps({'device':(name+'_')})) #Same as above line, but this one is for a duplicate turbine that will be visible on the Wind Plant Observer dashboard.
		MQTT.publish(topicAttr,json.dumps({name:{'latitude':latitude,'longitude':longitude}})) #Tell thingsboard the position of this turbine
		MQTT.publish(topicAttr,json.dumps({(name+'_'):{'latitude':latitude,'longitude':longitude}})) #Same as above line, but this one is for a duplicate turbine that will be visible on the Wind Plant Observer dashboard.
		#MQTT.publish(topicAttr,json.dumps({name:{'startButton':False}}), qos=1, retain=True) #Comment this out after the first time you run the program. The first time you need it to establish these attributes.
		#MQTT.publish(topicAttr,json.dumps({name:{'stopButton':False}}), qos=1, retain=True) #Comment this out after the first time you run the program. The first time you need it to establish these attributes.
		#genData[name] = {'day':time.localtime().tm_mday,'dailyGen':0,'month':time.localtime().tm_mon,'monthlyGen':0} #Comment this and the next two lines out after the first time you run the program. This creates the genBackup.txt file if it doesn't already exist. If it does exist, these lines will overwrite the existing data with 0s.
	#with open('genBackupFile.txt', 'w') as fp:
	#	json.dump(genData, fp)		
	with open('genBackupFile.txt') as e : #read backup file containing latest daily and monthly production totals
		genData = json.load(e)
	return addr2name, name2addr, lastMessageTime, genData

#This processes RPC messages received from the thingsboard switches    
def switch_message(data): #process an RPC message received from one of the thingsboard switches.
	global safety_switch, turbineOnOff_switch
	print('RPC Switch message recieved', file=open(standardOutput, 'a'))
	name = data.get("device")
	method = data.get("data").get("method")
	try:
		if (method == "startButton"):
			print('Starting '+name, file=open(standardOutput, 'a'))
			print("toggling startt button", file=open(standardOutput, 'a'))
			pub = MQTT.publish(topicAttr, json.dumps({name:{'startButton':True}}), qos=1, retain=True) #toggle the thingsboard value of startButton
			pub.wait_for_publish()
			pub = MQTT.publish(topicAttr, json.dumps({name:{'startButton':False}}), qos=1, retain=True) #then toggle it back
			print("sending message to remote XBee", file=open(standardOutput, 'a'))
			remote = RemoteXBeeDevice(xbee, XBee64BitAddress.from_hex_string(name2addr.get(name)))
			xbee.send_data(remote, "start") #Send start message to remote XBee
			print((name+',start,'+time.ctime()[4:]), file=open('windFarmData/eventLog.csv', 'a')) #print this event to the eventLog file
		elif (method == "stopButton"):
			print('Stoping '+name, file=open(standardOutput, 'a'))
			print('Toggling stop button', file=open(standardOutput, 'a'))
			pub = MQTT.publish(topicAttr, json.dumps({name:{'stopButton':True}}), qos=1, retain=True) #toggle the thingsboard value of stopButton
			pub.wait_for_publish()
			pub = MQTT.publish(topicAttr, json.dumps({name:{'stopButton':False}}), qos=1, retain=True) #then toggle it back
			print('sending message to remote XBee', file=open(standardOutput, 'a'))
			remote = RemoteXBeeDevice(xbee, XBee64BitAddress.from_hex_string(name2addr.get(name)))
			xbee.send_data(remote, "stop")
			print((name+',stop,'+time.ctime()[4:]), file=open('windFarmData/eventLog.csv', 'a')) #print this event to the eventLog file
		pub = MQTT.publish(topicAttr, json.dumps({name:{'turbineResponisive':True}}), qos=1, retain=True) #tell thingsboard that the start/stop message was successfully sent to the turbine
	except:
		print(name+' not found!', file=open(standardOutput, 'a'))
		pub = MQTT.publish(topicAttr, json.dumps({name:{'turbineResponisive':False}}), qos=1, retain=True) #tell thingsboard that the start/stop message was not successfully sent to the turbine
		

# this loop runs in parallel to the main loop using threading. It continuously listens for messages from thingsboard then calls the appropriate function to process the message.
def listener():
	while True:
		time.sleep(.1)
		global MQTT_message, new_MQTT_message	
		if new_MQTT_message:
			new_MQTT_message = False
			if MQTT_message.topic[0:14] == 'v1/gateway/rpc' : #This is an RPC message from one of the switches
				print("message recieved", file=open(standardOutput, 'a'))
				switch_message(json.loads(MQTT_message.payload)) 
			else:
				print('Message type not recognized!!!', file=open(standardOutput, 'a'))
				
MQTT = mqtt.Client(mqttClientId,clean_session=False)
MQTT.username_pw_set(mqttUserName) 
MQTT.connect(mqttBroker)
MQTT.on_connect = on_connect #call on_connect() when MQTT connects to the mqtt broker.
MQTT.on_message = on_message #call on_message() whenever a message is received from the mqtt broker.
addr2name, name2addr, lastMessageTime, genData = readTurbineInputFile()

MQTT.loop_start()

new_MQTT_message = False
T = threading.Thread(target=listener)
T.daemon = True #This means the thread will automatically quit if main program quits
T.start()

###################################################################################
### Part 2: XBee stuff
################################################################################### 
		
def data_receive_callback(xbee_message): #Called when the local XBee receives a data message. This is used for receiving power production data.
	print('pulse count received', file=open(standardOutput, 'a'))
	pulseCount = (256*xbee_message.data[0]+xbee_message.data[1]) #number of pulses counted in the last 15 minutes
	print("From"+str(xbee_message.remote_device.get_64bit_addr())+" >> Pulse count = "+str(pulseCount), file=open(standardOutput, 'a'))
	if (systemDemo == True):
		pulseCount = randint(400, 500) #We're not actually measuring power at this point, so I'm going to generate a random number and pretent it's the production.
		print("systemDemo enabled. Simulated pulseCount = "+str(pulseCount), file=open(standardOutput, 'a'))
	pulsePower = .1 #.05 kW-hr per meter pulse, but our software only captures every other pulse. 
	avgPower = round(pulseCount*pulsePower*4,1) #Average power production over the last 15 minutes. It's rounded to the first decimal point to prevent the weird .0000000000000001 terms you sometimes get from floating point arithmetic. 
	turbineName = addr2name[str(xbee_message.remote_device.get_64bit_addr())] #find the name of the turbine that sent this message
	genData[turbineName]['dailyGen'] = genData[turbineName]['dailyGen'] + round(pulsePower*pulseCount,1) #Add the energy generation from the past 15 minutes to the daily cumulative total (kw-hr).
	genData[turbineName]['monthlyGen'] = genData[turbineName]['monthlyGen'] + round(pulsePower*pulseCount,1) #Add the energy generation from the past 15 minutes to the monthly cumulative total (kw-hr).
	#print(genData, file=open(standardOutput, 'a'))
	message = {turbineName:[{'ts':1000*xbee_message.timestamp, 'values':{'Power':avgPower}}]}
	message_ = {(turbineName+'_'):[{'ts':1000*xbee_message.timestamp, 'values':{'Power':avgPower}}]} #This message will be sent to the turbine object visible on the Wind Farm Observer dashboard
	print(message, file=open(standardOutput, 'a'))
	a = MQTT.publish(topicTelem, json.dumps(message), qos=1, retain=True)
	MQTT.publish(topicTelem, json.dumps(message_), qos=1, retain=True) #Send data to Wind Farm Observer dassboard
	print(a, file=open(standardOutput, 'a'))
	print((turbineName+','+str(avgPower)+','+time.ctime()[4:]), file=open(('windFarmData/'+turbineName+'_pwrData.csv'), 'a')) #print this power production data to the log file associated with this turbine.
	MQTT.publish(topicAttr, json.dumps({turbineName: {'comm_error': False}}), qos=1, retain=True)
	MQTT.publish(topicAttr, json.dumps({(turbineName+'_'): {'comm_error': False}}), qos=1, retain=True)#Send data to Wind Farm Observer dashboard
	lastMessageTime[turbineName] = time.time() #record the time this message was processed in seconds since epoch. (since the last message time wasn't set in the call to io_sample_callback().

def io_sample_callback(io_sample, remote_xbee, send_time): #Called when the local XBee receives an IO Sampling message. Used to detect changes in rotor brake or turbine faults.
	print("IO sample received at time %s." % str(send_time), file=open(standardOutput, 'a'))
	turbineName = addr2name[str(remote_xbee.get_64bit_addr())] #find the name of the turbine that sent this message
	print(turbineName, file=open(standardOutput, 'a'))
	if (io_sample.get_digital_value(IOLine.DIO4_AD4) == IOValue.HIGH): #first process the part of the data telling us if the turbine is on or off
		IOData = {'brake_on':'true'}
		print('Brake on!', file=open(standardOutput, 'a'))
		print((turbineName+',Brake on,'+time.ctime()[4:]), file=open('windFarmData/'+turbineName+'_eventLog.csv', 'a')) #print this event to the eventLog file
	else:
		IOData = {'brake_on':'false'}
		print('Brake off!', file=open(standardOutput, 'a'))
		print((turbineName+',Brake off,'+time.ctime()[4:]), file=open('windFarmData/'+turbineName+'_eventLog.csv', 'a')) #print this event to the eventLog file
	any_fault = False #then process the part of the data telling us if any faults were detected. 
	for x in faultMap.keys() : #we're going to cycle through all the key:value pairs in faultMap
		if (io_sample.get_digital_value(x) == IOValue.HIGH):
			IOData[faultMap[x]] = 'true'
			print((turbineName+','+faultMap[x]+' fault detected,'+time.ctime()[4:]), file=open('windFarmData/'+turbineName+'_eventLog.csv', 'a')) #print this event to the eventLog file
			any_fault = True
		else:
			IOData[faultMap[x]] = 'false'
	IOData['any_fault'] = any_fault
	print('IOData: '+str(IOData), file=open(standardOutput, 'a'))
	#finally, put everything together and publish the data to thingsboard
	message = {turbineName: IOData}
	message_ = {(turbineName+'_'): IOData}
	print(message, file=open(standardOutput, 'a'))
	MQTT.publish(topicAttr, json.dumps(message), qos=1, retain=True)
	MQTT.publish(topicAttr, json.dumps(message_), qos=1, retain=True) #Send data to Wind Farm Observer dashboard
	
	MQTT.publish(topicAttr, json.dumps({turbineName: {'comm_error': False}}), qos=1, retain=True)
	MQTT.publish(topicAttr, json.dumps({(turbineName+'_'): {'comm_error': False}}), qos=1, retain=True)#Send data to Wind Farm Observer dashboard	
	lastMessageTime[turbineName] = time.time() #record the time this message was processed in seconds since epoch.


try:
	xbee = XBeeDevice(localXBeePort, 9600) 
	xbee.open()
	xbee.add_data_received_callback(data_receive_callback)		# Subscribe to data message reception (for power pulse count data).
	xbee.add_io_sample_received_callback(io_sample_callback)	# Subscribe to IO samples reception.
	print("Waiting for data...\n", file=open(standardOutput, 'a'))
	while True:
		for name in name2addr.keys() : #we're going to cycle through our list of turbines to check a few things.
			try: #first try to poll all of the turbines to get an update on their fault and on/off status
				remote = RemoteXBeeDevice(xbee, XBee64BitAddress.from_hex_string(name2addr.get(name)))
				io_sample_callback(remote.read_io_sample(),remote,(1000*time.time()))
			except: #if we don't get a reply, check to see how long it has been since we heard from this turbine. If it has been more than an hour, publish comm_error = true
				print("Failed to get I/O data from "+name+" at t = "+num2str(1000*time.time()), file=open(standardOutput, 'a'))
			if ((time.time() - lastMessageTime[name]) > 3600):
				MQTT.publish(topicAttr, json.dumps({name: {'comm_error': True}}), qos=1, retain=True)
				MQTT.publish(topicAttr, json.dumps({(name+'_'): {'comm_error': True}}), qos=1, retain=True) #Send data to Wind Farm Observer dashboard
			if (genData[name]['day'] != time.localtime().tm_mday): #If it is a new day
				message = {name:[{'ts':1000*(time.time()-43200), 'values':{'daily_gen':genData[name]['dailyGen']}}]} #Note: timestamp is shifted by 12 hours (4,3200 s) so this data point is graphed in the middle of the previous day
				message_ = {(name+'_'):[{'ts':1000*(time.time()-43200), 'values':{'daily_gen':genData[name]['dailyGen']}}]}
				MQTT.publish(topicTelem, json.dumps(message), qos=1, retain=True) #publish yesterday's cumulative power production to the Wind farm Controller dashboard in thingsboard.
				MQTT.publish(topicTelem, json.dumps(message_), qos=1, retain=True) #same, but for the Wind Farm Observer dashboard
				genData[name]['dailyGen'] = 0 #Reset daily production counter.
				genData[name]['day'] = time.localtime().tm_mday #update the production day
			if (genData[name]['month'] != time.localtime().tm_mon): #If it is a new month
				message = {name:[{'ts':1000*(time.time()-1296000), 'values':{'monthly_gen':genData[name]['monthlyGen']}}]} #Note: timestamp is shifted by 15 days (1,296,000 s) so this data point is graphed in the middle of the previous month
				message_ = {(name+'_'):[{'ts':1000*(time.time()-1296000), 'values':{'monthly_gen':genData[name]['monthlyGen']}}]}
				MQTT.publish(topicTelem, json.dumps(message), qos=1, retain=True) #publish last month's cumulative power production to the Wind farm Controller dashboard in thingsboard.
				MQTT.publish(topicTelem, json.dumps(message_), qos=1, retain=True) #same, but for the Wind Farm Observer dashboard
				genData[name]['monthlyGen'] = 0 #Reset daily production counter.
				genData[name]['month'] = time.localtime().tm_mon #update the production day
		with open('genBackupFile.txt', 'w') as fp: #Write daily and monthly cumulative generation data to genBackupFile.txt so that data can be recovered if the system goes down or reboots.
			json.dump(genData, fp)
		time.sleep(900) #sleep for 15 minutes
		
				
		
		
				
finally:
	if xbee is not None and xbee.is_open():
		print("closing local XBee", file=open(standardOutput, 'a'))
		xbee.close()
