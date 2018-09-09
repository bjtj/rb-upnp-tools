require 'test/unit'
require_relative '../lib/upnp_model.rb'

class TestUPnPModel < Test::Unit::TestCase

  def test_device_list
    udn = 'uuid:' + SecureRandom::uuid
    root_device = UPnPDevice.new
    root_device.udn = udn
    root_device.device_type = 'device-type1'

    device = UPnPDevice.new
    device.udn = udn
    device.device_type = 'device-type2'
    root_device.child_devices << device

    device = UPnPDevice.new
    device.udn = udn
    device.device_type = 'device-type3'
    root_device.child_devices << device

    device = UPnPDevice.new
    device.udn = udn
    device.device_type = 'device-type4'

    child_device = UPnPDevice.new
    child_device.udn = udn
    child_device.device_type = 'device-type5'
    device.child_devices << child_device
    
    root_device.child_devices << device

    root_device.all_devices.each do |device|
      puts device.device_type
    end

    puts root_device.all_usn
    
  end

  def test_service_list
    udn = 'uuid:' + SecureRandom::uuid
    root_device = UPnPDevice.new
    root_device.udn = udn
    root_device.device_type = 'device-type1'

    service = UPnPService.new
    service.service_type = 'service-type1'
    root_device.services << service

    service = UPnPService.new
    service.service_type = 'service-type2'
    root_device.services << service

    device = UPnPDevice.new
    device.udn = udn
    device.device_type = 'device-type2'
    root_device.child_devices << device

    device = UPnPDevice.new
    device.udn = udn
    device.device_type = 'device-type3'
    root_device.child_devices << device

    device = UPnPDevice.new
    device.udn = udn
    device.device_type = 'device-type4'

    service = UPnPService.new
    service.service_type = 'service-type3'
    device.services << service

    child_device = UPnPDevice.new
    child_device.udn = udn
    child_device.device_type = 'device-type5'
    device.child_devices << child_device

    service = UPnPService.new
    service.service_type = 'service-type4'
    device.services << service
    
    root_device.child_devices << device

    root_device.all_services.each do |service|
      puts service.service_type
    end

    puts root_device.all_usn
    
  end

  def test_usn_list
    device = UPnPDevice.new
    device.udn = 'udn-x'
    device.device_type = 'device-type1'
    
    service = UPnPService.new
    service.service_type = 'service-type1'
    device.services << service

    service = UPnPService.new
    service.service_type = 'service-type2'
    device.services << service

    usn_list = device.all_usn
    puts usn_list
  end

  def test_device_description
    device = UPnPDevice.read open('../res/device.xml').read
    puts device
  end
  
  def test_device
    xml = '<device>
    <deviceType>urn:schemas-upnp-org:device:DimmableLight:1</deviceType>
	<friendlyName>UPnP Sample Dimmable Light ver.1</friendlyName>
	<manufacturer>Testers</manufacturer>
	<manufacturerURL>www.example.com</manufacturerURL>
	<modelDescription>UPnP Test Device</modelDescription>
	<modelName>UPnP Test Device</modelName>
	<modelNumber>1</modelNumber>
	<modelURL>www.example.com</modelURL>
	<serialNumber>12345678</serialNumber>
	<UDN>e399855c-7ecb-1fff-8000-000000000000</UDN>
    </device>'

    device = UPnPDevice.new
    device.device_type = 'urn:schemas-upnp-org:device:DimmableLight:1'
	device.friendly_name = 'UPnP Sample Dimmable Light ver.1'
	device.manufacturer = 'Testers'
	device.manufacturer_url = 'www.example.com'
	device.model_description = 'UPnP Test Device'
	device.model_name = 'UPnP Test Device'
	device.model_number = '1'
	device.model_url = 'www.example.com'
	device.serial_number = '12345678'
    device.udn = 'e399855c-7ecb-1fff-8000-000000000000'
    puts device.to_xml
    
    assert_equal xml.gsub(/>\s+</, '><'), device.to_xml


    service = UPnPService.new
    service.service_type = 'urn:schemas-upnp-org:service:SwitchPower:1'
	service.service_id = 'urn:upnp-org:serviceId:SwitchPower.1'
	service.scpdurl = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/scpd.xml'
	service.control_url = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/control.xml'
	service.event_sub_url = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/event.xml'
    device.services << service


    service = UPnPService.new
    service.service_type = 'urn:schemas-upnp-org:service:Dimming:1'
	service.service_id = 'urn:upnp-org:serviceId:Dimming.1'
	service.scpdurl = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/scpd.xml'
	service.control_url = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/control.xml'
	service.event_sub_url = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/event.xml'
    device.services << service

    assert_equal device.to_xml, UPnPDevice.read(open('../res/device.xml').read).to_xml
    
  end

  def test_service
    xml = '<service>
		<serviceType>urn:schemas-upnp-org:service:SwitchPower:1</serviceType>
		<serviceId>urn:upnp-org:serviceId:SwitchPower.1</serviceId>
		<SCPDURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/scpd.xml</SCPDURL>
		<controlURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/control.xml</controlURL>
		<eventSubURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/event.xml</eventSubURL>
	  </service>'

    # puts xml.gsub(/\s+/, '')

    service = UPnPService.new
    service.service_type = 'urn:schemas-upnp-org:service:SwitchPower:1'
    service.service_id = 'urn:upnp-org:serviceId:SwitchPower.1'
	service.scpdurl = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/scpd.xml'
	service.control_url = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/control.xml'
    service.event_sub_url = '/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/event.xml'

    # puts service.to_xml

    assert_equal xml.gsub(/\s+/, ''), service.to_xml

  end

  def test_scpd_gen
    scpd = UPnPScpd.new
    
    action = UPnPAction.new
    action.name = 'SetLoadLevelTarget'
    argument = UPnPActionArgument.new
    argument.name = 'newLoadlevelTarget'
    argument.direction = 'in'
    argument.related_state_variable = 'LoadLevelTarget'
    action.arguments << argument
    scpd.actions << action

    action = UPnPAction.new
    action.name = 'GetLoadLevelTarget'
    argument = UPnPActionArgument.new
    argument.name = 'GetLoadlevelTarget'
    argument.direction = 'out'
    argument.related_state_variable = 'LoadLevelTarget'
    action.arguments << argument
    scpd.actions << action

    action = UPnPAction.new
    action.name = 'GetLoadLevelStatus'
    argument = UPnPActionArgument.new
    argument.name = 'retLoadlevelStatus'
    argument.direction = 'out'
    argument.related_state_variable = 'LoadLevelStatus'
    action.arguments << argument
    scpd.actions << action


    state_variable = UPnPStateVariable.new
    state_variable.name = 'LoadLevelTarget'
    state_variable.data_type = 'ui1'
    state_variable.send_events = 'no'
    scpd.state_variables << state_variable

    state_variable = UPnPStateVariable.new
    state_variable.name = 'LoadLevelStatus'
    state_variable.data_type = 'ui1'
    state_variable.send_events = 'yes'
    scpd.state_variables << state_variable
    
    # puts scpd.to_xml

    assert_equal scpd.to_xml_doc, UPnPScpd.read(open('../res/scpd.xml').read).to_xml_doc
    
    
  end

  def test_scpd_parse
    scpd = UPnPScpd.read open('../res/scpd.xml').read
    # puts scpd.to_xml

    # puts '----- actions -----'

    # scpd.actions.each { |action|
    #   puts action
    #   puts action.arguments
    # }

    # puts '----- state variables -----'

    # scpd.state_variables.each { |state_variable|
    #   puts state_variable
    # }
  end
end

