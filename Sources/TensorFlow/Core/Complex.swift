public struct Complex<T : FloatingPoint> {
  public var real: T
  public var imaginary: T

  public init(real: T = 0, imaginary: T = 0) {
	self.real = real
	self.imaginary = imaginary
  }
}

extension Complex : Differentiable where T : Differentiable {
  public typealias TangentVector = Complex
  public typealias AllDifferentiableVariables = Complex
}

extension Complex {
  @inlinable
  public static var i: Complex {
    return Complex(real: 0, imaginary: 1)
  }

  @inlinable
  public var isFinite: Bool {
    return real.isFinite && imaginary.isFinite
  }

  @inlinable
  public var isInfinite: Bool {
    return real.isInfinite || imaginary.isInfinite
  }

  @inlinable
  public var isNaN: Bool {
    return (real.isNaN && !imaginary.isInfinite) ||
      (imaginary.isNaN && !real.isInfinite)
  }

  @inlinable
  public var isZero: Bool {
    return real.isZero && imaginary.isZero
  }
}

extension Complex : ExpressibleByIntegerLiteral {
  @inlinable
  public init(integerLiteral value: Int) {
    self.real = T(value)
    self.imaginary = 0
  }
}

extension Complex : CustomStringConvertible {
  @inlinable
  public var description: String {
    return real.isNaN && real.sign == .minus
      ? imaginary.sign == .minus
        ? "-\(-real) - \(-imaginary)i"
        : "-\(-real) + \(imaginary)i"
      : imaginary.sign == .minus
        ? "\(real) - \(-imaginary)i"
        : "\(real) + \(imaginary)i"
  }
}

extension Complex : Equatable {
  @inlinable
  public static func == (lhs: Complex, rhs: Complex) -> Bool {
    return lhs.real == rhs.real && lhs.imaginary == rhs.imaginary
  }
}

extension Complex : AdditiveArithmetic {
  @inlinable
  @differentiable(vjp: _vjpAdd(lhs:rhs:) where T : Differentiable)
  public static func + (lhs: Complex, rhs: Complex) -> Complex {
    var lhs = lhs
    lhs += rhs
    return lhs
  }

  @inlinable
  public static func += (lhs: inout Complex, rhs: Complex) {
    lhs.real += rhs.real
    lhs.imaginary += rhs.imaginary
  }

  @inlinable
  @differentiable(vjp: _vjpSubtract(lhs:rhs:) where T : Differentiable)
  public static func - (lhs: Complex, rhs: Complex) -> Complex {
    var lhs = lhs
    lhs -= rhs
    return lhs
  }

  @inlinable
  public static func -= (lhs: inout Complex, rhs: Complex) {
    lhs.real -= rhs.real
    lhs.imaginary -= rhs.imaginary
  }
}

extension Complex : Numeric {
  public init?<U>(exactly source: U) where U : BinaryInteger {
    guard let t = T(exactly: source) else { return nil }
    self.real = t
    self.imaginary = 0
  }

  @inlinable
  @differentiable(vjp: _vjpMultiply(lhs:rhs:) where T : Differentiable)
  public static func * (lhs: Complex, rhs: Complex) -> Complex {
    var a = lhs.real, b = lhs.imaginary, c = rhs.real, d = rhs.imaginary
    let ac = a * c, bd = b * d, ad = a * d, bc = b * c
    let x = ac - bd
    let y = ad + bc

    if x.isNaN && y.isNaN {
      var recalculate = false
      if a.isInfinite || b.isInfinite {
        a = T(signOf: a, magnitudeOf: a.isInfinite ? 1 : 0)
        b = T(signOf: b, magnitudeOf: b.isInfinite ? 1 : 0)
        if c.isNaN { c = T(signOf: c, magnitudeOf: 0) }
        if d.isNaN { d = T(signOf: d, magnitudeOf: 0) }
        recalculate = true
      }
      if c.isInfinite || d.isInfinite {
        if a.isNaN { a = T(signOf: a, magnitudeOf: 0) }
        if b.isNaN { b = T(signOf: b, magnitudeOf: 0) }
        c = T(signOf: c, magnitudeOf: c.isInfinite ? 1 : 0)
        d = T(signOf: d, magnitudeOf: d.isInfinite ? 1 : 0)
        recalculate = true
      }
      if !recalculate &&
        (ac.isInfinite || bd.isInfinite || ad.isInfinite || bc.isInfinite) {
        if a.isNaN { a = T(signOf: a, magnitudeOf: 0) }
        if b.isNaN { b = T(signOf: b, magnitudeOf: 0) }
        if c.isNaN { c = T(signOf: c, magnitudeOf: 0) }
        if d.isNaN { d = T(signOf: d, magnitudeOf: 0) }
        recalculate = true
      }
      if recalculate {
        return Complex(
          real: .infinity * (a * c - b * d),
          imaginary: .infinity * (a * d + b * c)
        )
      }
    }
    return Complex(real: x, imaginary: y)
  }

  @inlinable
  public static func *= (lhs: inout Complex, rhs: Complex) {
    lhs = lhs * rhs
  }

  @inlinable
  public var magnitude: T {
    var x = abs(real)
    var y = abs(imaginary)
    if x.isInfinite { return x }
    if y.isInfinite { return y }
    if x == 0 { return y }
    if x < y { swap(&x, &y) }
    let ratio = y / x
    return x * (1 + ratio * ratio).squareRoot()
  }
}

extension Complex : SignedNumeric {
  @inlinable
  @differentiable(vjp: _vjpNegate where T : Differentiable)
  public static prefix func - (operand: Complex) -> Complex {
    return Complex(real: -operand.real, imaginary: -operand.imaginary)
  }

  @inlinable
  public mutating func negate() {
    real.negate()
    imaginary.negate()
  }
}

extension Complex {
  @inlinable
  @differentiable(vjp: _vjpDivide(lhs:rhs:) where T : Differentiable)
  public static func / (lhs: Complex, rhs: Complex) -> Complex {
    var a = lhs.real, b = lhs.imaginary, c = rhs.real, d = rhs.imaginary
    var x: T
    var y: T
    if c.magnitude >= d.magnitude {
      let ratio = d / c
      let denominator = c + d * ratio
      x = (a + b * ratio) / denominator
      y = (b - a * ratio) / denominator
    } else {
      let ratio = c / d
      let denominator = c * ratio + d
      x = (a * ratio + b) / denominator
      y = (b * ratio - a) / denominator
    }
    if x.isNaN && y.isNaN {
      if c == 0 && d == 0 && (!a.isNaN || !b.isNaN) {
        x = T(signOf: c, magnitudeOf: .infinity) * a
        y = T(signOf: c, magnitudeOf: .infinity) * b
      } else if (a.isInfinite || b.isInfinite) && c.isFinite && d.isFinite {
        a = T(signOf: a, magnitudeOf: a.isInfinite ? 1 : 0)
        b = T(signOf: b, magnitudeOf: b.isInfinite ? 1 : 0)
        x = .infinity * (a * c + b * d)
        y = .infinity * (b * c - a * d)
      } else if (c.isInfinite || d.isInfinite) && a.isFinite && b.isFinite {
        c = T(signOf: c, magnitudeOf: c.isInfinite ? 1 : 0)
        d = T(signOf: d, magnitudeOf: d.isInfinite ? 1 : 0)
        x = 0 * (a * c + b * d)
        y = 0 * (b * c - a * d)
      }
    }
    return Complex(real: x, imaginary: y)
  }

  @inlinable
  public static func /= (lhs: inout Complex, rhs: Complex) {
    lhs = lhs / rhs
  }
}

extension Complex {
  @inlinable
  public func complexConjugate() -> Complex {
    return Complex(real: real, imaginary: -imaginary)
  }
}

@inlinable
public func abs<T>(_ z: Complex<T>) -> Complex<T> {
  return Complex(real: z.magnitude)
}

extension Complex {
  @inlinable
  @differentiable(vjp: _vjpAdding(real:) where T : Differentiable, T.TangentVector == T)
  public func adding(real: T) -> Complex {
    var c = self
    c.real += real
    return c
  }

  @inlinable
  @differentiable(vjp: _vjpSubtracting(real:) where T : Differentiable, T.TangentVector == T)
  public func subtracting(real: T) -> Complex {
    var c = self
    c.real -= real
    return c
  }

  @inlinable
  @differentiable(vjp: _vjpAdding(imaginary:) where T : Differentiable, T.TangentVector == T)
  public func adding(imaginary: T) -> Complex {
    var c = self
    c.imaginary += imaginary
    return c
  }
  
  @inlinable
  @differentiable(vjp: _vjpSubtracting(imaginary:) where T : Differentiable, T.TangentVector == T)
  public func subtracting(imaginary: T) -> Complex {
    var c = self
    c.imaginary -= imaginary
    return c
  }
}

extension Complex where T : Differentiable {
  @inlinable
  static func _vjpAdd(lhs: Complex, rhs: Complex) 
  -> (Complex, (Complex) -> (Complex, Complex)) {
    return (lhs * rhs, { v in (v, v) })
  }

  @inlinable
  static func _vjpSubtract(lhs: Complex, rhs: Complex) 
  -> (Complex, (Complex) -> (Complex, Complex)) {
    return (lhs * rhs, { v in (v, -v) })
  }

  @inlinable
  static func _vjpMultiply(lhs: Complex, rhs: Complex) 
  -> (Complex, (Complex) -> (Complex, Complex)) {
    return (lhs * rhs, { v in (rhs * v, lhs * v) })
  }

  @inlinable
  static func _vjpDivide(lhs: Complex, rhs: Complex) 
  -> (Complex, (Complex) -> (Complex, Complex)) {
    return (lhs * rhs, { v in (v / rhs, -lhs / (rhs * rhs) * v) })
  }

  @inlinable
  static func _vjpNegate(operand: Complex)
  -> (Complex, (Complex) -> Complex) {
    return (-operand, { v in -v})
  }
}

extension Complex where T : Differentiable, T.TangentVector == T {
  @inlinable
  func _vjpAdding(real: T) -> (Complex, (Complex) -> (Complex, T)) {
    return (self.adding(real: real), { ($0, $0.real) })
  }

  @inlinable
  func _vjpSubtracting(real: T) -> (Complex, (Complex) -> (Complex, T)) {
    return (self.subtracting(real: real), { ($0, -$0.real) })
  }

  @inlinable
  func _vjpAdding(imaginary: T) -> (Complex, (Complex) -> (Complex, T)) {
    return (self.adding(real: real), { ($0, $0.imaginary) })
  }

  @inlinable
  func _vjpSubtracting(imaginary: T) -> (Complex, (Complex) -> (Complex, T)) {
    return (self.subtracting(real: real), { ($0, -$0.imaginary) })
  }
}
