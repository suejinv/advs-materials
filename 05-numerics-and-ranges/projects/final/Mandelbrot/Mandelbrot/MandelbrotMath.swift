/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Numerics
import CoreGraphics

/// Uninhabited type for Mandelbrot math related methods.
enum MandelbrotMath {
  /// Points that describe the evolution points
  static func points<RealType: Real>(start: Complex<RealType>,
                                     maxIterations: Int)
    -> [Complex<RealType>] {


    var results: [Complex<RealType>] = []
    results.reserveCapacity(maxIterations)

    var z = Complex<RealType>.zero
    for _ in 0..<maxIterations {
      z = z * z + start
      defer {
        results.append(z) // always add this point, even if early exit
      }
      // Mathematically, if z > 2, the point will not be part of the
      // Mandelbrot set.
      if z.lengthSquared > 4 {
        break
      }
    }

    return results
  }

  /// Compute the number of iterations before divergence upto maxIterations.
  @inlinable
  static func iterations<RealType: Real>(start: Complex<RealType>, max: Int) -> Int {
    var z = Complex<RealType>.zero
    var iteration = 0
    while z.lengthSquared <= 4 && iteration < max {
      z = z * z + start
      iteration += 1
    }
    return iteration
  }

  /// Compute an Mandelbrot image
  static func makeImage<RealType: Real & CGFloatConvertable>(
    for realType: RealType.Type,
    imageSize: CGSize,
    displayToModel: CGAffineTransform,
    maxIterations: Int,
    palette: PixelPalette
  ) -> CGImage? {
    let width = Int(imageSize.width)
    let height = Int(imageSize.height)

    let scale = displayToModel.a
    let upperLeft = CGPoint.zero.applying(displayToModel)

    let bitmap = Bitmap<ColorPixel>(width: width, height: height) { width, height, buffer in
      for y in 0 ..< height {
        for x in 0 ..< width {
          let position = Complex(
            RealType(upperLeft.x + CGFloat(x) * scale),
            RealType(upperLeft.y - CGFloat(y) * scale))
          let iterations =
            MandelbrotMath.iterations(start: position, max: maxIterations)
          buffer[x + y * width] = palette.values[iterations % palette.values.count]
        }
      }
    }
    return bitmap.cgImage
  }

  static func makeImageSIMD8_Float64(
    imageSize: CGSize,
    displayToModel: CGAffineTransform,
    maxIterations: Int,
    palette: PixelPalette
  ) -> CGImage? {
    // swiftlint:disable nesting
    typealias SIMDX = SIMD8
    typealias ScalarFloat = Float64
    typealias ScalarInt = Int64
    // swiftlint:enable nesting

    let width = Int(imageSize.width)
    let height = Int(imageSize.height)

    let scale = ScalarFloat(displayToModel.a)
    let upperLeft = CGPoint.zero.applying(displayToModel)
    let left = ScalarFloat(upperLeft.x)
    let upper = ScalarFloat(upperLeft.y)

    let fours = SIMDX(repeating: ScalarFloat(4))
    let twos = SIMDX(repeating: ScalarFloat(2))
    let ones = SIMDX<ScalarInt>.one
    let zeros = SIMDX<ScalarInt>.zero

    let bitmap = Bitmap<ColorPixel>(width: width, height: height) { width, height, buffer in
      let scalarCount = SIMDX<Int64>.scalarCount

      var realZ: SIMDX<ScalarFloat>
      var imaginaryZ: SIMDX<ScalarFloat>
      var counts: SIMDX<ScalarInt>
      let initialMask = fours .> fours // all false
      var stopIncrementMask = initialMask
      let ramp = SIMDX((0..<scalarCount).map { left + ScalarFloat($0) * scale })

      for y in 0 ..< height {
        let imaginary = SIMDX(repeating: upper - ScalarFloat(y) * scale)

        for x in 0 ..< width / scalarCount {
          let real = SIMDX(repeating: ScalarFloat(x * scalarCount) * scale) + ramp

          realZ = .zero
          imaginaryZ = .zero
          counts = .zero
          stopIncrementMask = initialMask

          for _ in 0..<maxIterations {
            let realZ2 = realZ * realZ
            let imaginaryZ2 = imaginaryZ * imaginaryZ
            let realImaginaryTimesTwo = twos * realZ * imaginaryZ
            realZ = realZ2 - imaginaryZ2 + real
            imaginaryZ = realImaginaryTimesTwo + imaginary
            let newMask = (realZ2 + imaginaryZ2) .>= fours
            stopIncrementMask .|= newMask

            let incrementer = ones.replacing(with: zeros, where: stopIncrementMask)
            if incrementer == SIMDX<ScalarInt>.zero {
              break
            }
            counts &+= incrementer
          }

          let paletteSize = palette.values.count
          for index in 0 ..< scalarCount {
            buffer[x * scalarCount + index + y * width] = palette.values[Int(counts[index]) % paletteSize]
          }
        }
        // Process the remainder
        let remainder = width % scalarCount
        let lastIndex = width / scalarCount * scalarCount
        for index in (0 ..< remainder) {
          let start = Complex(
            left + ScalarFloat(lastIndex + index) * scale,
            upper - ScalarFloat(y) * scale)
          var z = Complex<ScalarFloat>.zero
          var iteration = 0
          while z.lengthSquared <= 4 && iteration < maxIterations {
            z = z * z + start
            iteration += 1
          }
          buffer[lastIndex + index + y * width] =
            palette.values[iteration % palette.values.count]
        }
      }
    }
    return bitmap.cgImage
  }
}
