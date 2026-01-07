class Numeric
  def to_fahrenheit
    ((self * 9.0 / 5.0) + 32).round(2)
  end

  def to_celsius
    ((self - 32) * 5.0 / 9.0).round(2)
  end

  def to_mph
    self * 1.60934
  end

  alias_method :to_fh, :to_fahrenheit
  alias_method :to_c, :to_celsius
end
