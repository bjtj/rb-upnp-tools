require 'nokogiri'
require_relative 'upnp_xml.rb'


class UPnPModel < Hash
end


class UPnPDevice < UPnPModel
  def initialize
    @child_devices = []
    @services = []
  end

  attr_accessor :base_url
  attr_accessor :child_devices
  attr_accessor :services

  def all_devices
    devices = @child_devices
    @child_devices.each do |device|
      devices += device.all_devices
    end
    return devices
  end

  def all_services
    services = @services
    @child_devices.each do |device|
      services += device.all_services
    end
    return services
  end

  def to_xml
    device = XmlTag.new 'device'
    self.each { |k,v|
      device.append(XmlTag.new(k)).append(XmlText.new(v))
    }

    serviceList = device.append XmlTag.new('serviceList')
    @services.each { |service|
      serviceList.append service.to_xml
    }

    deviceList = device.append XmlTag.new('deviceList')
    @children.each { |device|
      deviceList.append device.to_xml
    }
  end
end

def UPnPDevice.to_xml_doc(device)
  root = XmlTag.new 'root'
  root.attributes['xmlns'] = 'urn:schemas-upnp-org:device-1-0'

  specVersion = root.append(XmlTag.new('specVersion'))
  specVersion.append(XmlTag.new('major')).append(XmlText.new(1))
  specVersion.append(XmlTag.new('major')).append(XmlText.new(0))
  
  root.append device.to_xml
  return '<?xml version="1.0"?>' + "\n#{root}"
end

def UPnPDevice.read(xml)
  doc = Nokogiri::XML(xml)
  doc.root.elements.each do |elem|
    if elem.name == 'device'
      return UPnPDevice.read_xml_node elem
    end
  end
  nil
end

def UPnPDevice.read_xml_node(node)
  device = UPnPDevice.new 
  node.elements.each do |elem|
    if elem.elements.empty?
      device[elem.name] = elem.text
    elsif elem.name == 'deviceList'
      elem.elements.each do |device_node|
        if device_node.name == 'device'
          device.child_devices << UPnPDevice.read_xml_node(device_node)
        end
      end
    elsif elem.name == 'serviceList'
      elem.elements.each do |service_node|
        if service_node.name == 'service'
          device.services << UPnPService.read_xml_node(service_node)
        end
      end
    end
  end
  device
end


class UPnPService < UPnPModel 
  attr_accessor :scpd

  def service_id
    self['serviceId']
  end
  
  def service_type
    self['serviceType']
  end

  def scpdurl
    self['SCPDURL']
  end

  def controlurl
    self['controlURL']
  end

  def eventsuburl
    self['eventSubURL']
  end

  def to_xml
    service = XmlTag.new 'service'
    self.each { |k,v|
      service.append(XmlTag.new(k)).append(XmlText.new(v))
    }
    return service.to_s
  end
end

def UPnPService.read_xml_node(node)
  service = UPnPService.new
  node.elements.each do |elem|
    if elem.elements.empty?
      service[elem.name] = elem.text
    end
  end
  service
end


class UPnPScpd < UPnPModel

  def initialize
    @actions = []
    @state_variables = []
  end
  
  attr_accessor :spec_version, :actions, :state_variables

  def to_xml
    scpd = XmlTag.new 'scpd'
    scpd.attributes['xmlns'] = 'urn:schemas-upnp-org:service-1-0'
    
    spec_version = scpd.append XmlTag.new('specVersion')
    spec_version.append(XmlTag.new('major')).append(XmlText.new(1))
    spec_version.append(XmlTag.new('minor')).append(XmlText.new(0))

    action_list = scpd.append XmlTag.new('actionList')
    @actions.each { |action|
      action_list.append action.to_xml
    }

    service_state_table = scp.dappend XmlTag.new('serviceStateTable');
    @state_variables.each { |state_variable|
      service_state_table.append state_variable.to_xml
    }
    return '<?xml version="1.0"?>' + "\n#{scpd}"
  end
end

def UPnPScpd.read(xml)
  scpd = UPnPScpd.new
  doc = Nokogiri::XML(xml)
  doc.root.elements.each do |elem|
    case elem.name
    when 'specVersion'
      scpd.spec_version = [1,0]
    when 'actionList'
      elem.elements.each { |action_node|
        if action_node.name == 'action'
          action = UPnPAction.read_xml_node(action_node)
          scpd.actions << action
        end
      }
    when 'serviceStateTable'
      elem.elements.each { |state_variable_node|
        if state_variable_node.name == 'stateVariable'
          state_variable = UPnPStateVariable.read_xml_node(state_variable_node)
          scpd.state_variables << state_variable
        end
      }
    end
  end
  return scpd
end


class UPnPAction < UPnPModel
  def initialize
    @arguments = []
  end

  attr_accessor :name
  attr_accessor :arguments

  def get_argument(name)
    @arguments.each { |argument|
      if argument.name == name
        return argument
      end
    }
    nil
  end

  def in_arguments
    @arguments.select { |argument| argument.direction == 'in' }
  end

  def out_arguments
    @arguments.select { |argument| argument.direction == 'out' }
  end

  def to_xml
    action = XmlTag.new 'action'
    
    prop = action.append XmlTag.new 'name'
    prop.append XmlText.new @name

    argument_list = action.append XmlTag.new 'argumentList'
    @arguments.each { |argument|
      argument_list.append argument.to_xml
    }

    return action.to_s
  end
end

def UPnPAction.read_xml_node(node)
  action = UPnPActionArgument.new
  node.elements.each do |elem|
    if elem.name == 'name'
      action.name = elem.text
    elsif elem.name == 'argumentList'
      elem.elements.each { |argument_node|
        if argument_node.name == 'argument'
          action.arguments << UPnPActionArgument.read_xml_node(argument_node)
        end
      }
    end
  end
  return action
end


class UPnPActionArgument < UPnPModel
  attr_accessor :name, :direction, :related_state_variable

  def to_xml
    argument = XmlTag.new 'argument'

    prop = argument.append XmlTag.new 'name'
    prop.append XmlText.new @name

    prop = argument.append XmlTag.new 'direction'
    prop.append XmlText.new @direction

    prop = argument.append XmlTag.new 'relatedStateVariable'
    prop.append XmlText.new @related_state_variable

    return argument.to_s
  end
end

def UPnPActionArgument.read_xml_node(node)
  argument = UPnPActionArgument.new
  node.elements.each do |elem|
    case elem.name
    when 'name'
      argument.name = elem.text
    when 'direction'
      argument.direction = elem.text
    when 'relatedStateVariable'
      argument.related_state_variable = elem.text
    end
  end
  return argument
end


class UPnPStateVariable < UPnPModel
  attr_accessor :name, :data_type, :send_events, :multicast

  def to_xml
    state_variable = XmlTag.new 'stateVariable'
    if @send_events != nil
      state_variable.attribute['sendEvents'] = @send_events
    end

    if @multicast != nil
      state_variable.attribute['multicast'] = @multicast
    end
    
    prop = argument.append XmlTag.new 'name'
    prop.append XmlText.new @name

    prop = argument.append XmlTag.new 'dataType'
    prop.append XmlText.new @data_type
    
    return state_variable.to_s
  end
end

def UPnPStateVariable.read_xml_node(node)
  state_variable = UPnPStateVariable.new
  state_variable.send_events = node.attribute('sendEvents')
  state_variable.multicast = node.attribute('multicast')
  node.elements.each do |elem|
    case elem.name
    when 'name'
      state_variable.name = elem.text
    when 'dataType'
      state_variable.data_type = elem.text
    end
  end
  return state_variable
end
