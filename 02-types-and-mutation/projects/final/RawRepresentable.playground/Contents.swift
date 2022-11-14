/// Sample code from the book, Expert Swift,
/// published at raywenderlich.com, Copyright (c) 2021 Razeware LLC.
/// See LICENSE for details. Thank you for supporting our work!
/// Visit https://www.raywenderlich.com/books/expert-swift

enum Coin: Int, CaseIterable {
  case penny = 1, nickel = 5, dime = 10, quarter = 25
}

let lucky = Coin(rawValue: 1)
print(lucky?.rawValue)
let notSoMuch = Coin(rawValue: 2)
print(notSoMuch?.rawValue)


struct Email: RawRepresentable {
  var rawValue: String

  init?(rawValue: String) {
    guard rawValue.contains("@") else {
      return nil
    }
    self.rawValue = rawValue
  }
}

let notEmail = Email(rawValue: "suejinv")
print(notEmail?.rawValue)
let email = Email(rawValue: "suejinv@naver.com")
print(email?.rawValue)

func send(message: String, to: Email) throws {

}


