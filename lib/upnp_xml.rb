

class XmlTag

  def initialize(name)
    @name = name
    @children = []
    @attributes = {}
  end

  attr_accessor :name, :attributes, :children

  def append(tag)
    @children.append(tag)
    return tag
  end
  
  def to_s
    elems = [@name] + @attributes.map {|k,v| "#{k}=\"#{v}\""}

    if @children.any?
      str = "<#{elems.join(' ')}>"
      str += @children.each {|elem| "#{elem}"}.join("")
      str += "</#{@name}>"
      return str
    else
      return "<#{elems.join(' ')} />"
    end
  end

end


class XmlText
  def initialize(text)
    @text = "#{text}"
    @text = escape(@text)
  end

  def escape(text)
    text.gsub('&', '&amp;').gsub('>', '&gt;').gsub('<', '&lt;')
  end

  def to_s
    @text
  end
end
