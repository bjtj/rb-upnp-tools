class Usn
  def initialize(udn, st)
    @udn = udn
    @st = st
  end

  def udn
    @udn
  end

  def st
    @st
  end

  def to_s
    if st.to_s.empty?
      return udn
    end
    return "#{udn}::#{st}"
  end
end

def Usn.read(text)
  tokens = text.split '::', 2
  udn = tokens[0]
  st = ''
  if tokens.length == 2
    st = tokens[1]
  end
  return Usn.new udn, st
end
