class FirstLine
  def initialize(tokens)
    @tokens = tokens
  end

  def [](key)
    @tokens[key]
  end

  def []=(key, value)
    @tokens[key] = value
  end

  def to_s
    @tokens.join(' ')
  end
end

def FirstLine.read(line)
  FirstLine.new line.split(%r{\s+}, 3)
end


class HttpHeader < Hash

  def initialize(firstline)
    @name_table = Hash.new
    @firstline = firstline
  end

  def firstline
    @firstline
  end

  def org_keys
    @name_table.values
  end
  
  def [](key)
    super _issensitive(key)
  end

  def []=(key, value)
    @name_table[_issensitive(key)] = key
    super _issensitive(key), value
  end

  def update!(hash)
    hash.each { |k,v| self[k] = v }
  end

  def to_s
    s = "#{firstline}\r\n"
    self.each do |key, value|
      s << "#{@name_table[key]}: #{value}\r\n"
    end
    s << "\r\n"
    return s
  end

  def to_str
    self.to_s
  end

  protected

  def _issensitive(key)
    key.respond_to?(:upcase) ? key.upcase : key
  end
end


def HttpHeader.read(text)
  firstline = text.lines[0].strip
  fields = text.lines[1..-1]
  header = HttpHeader.new FirstLine.read(firstline)
  fields.each do |line|
    tokens = line.split ':', 2
    name = tokens[0].strip
    value = tokens[1].strip
    header[name] = value
  end
  header
end
