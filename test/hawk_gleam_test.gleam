import event
import gleam/option
import gleam/string
import gleeunit
import hawk_gleam as hawk

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn send_before_init_returns_error_test() {
  // Arrange
  let payload = event.EventPayload("Test event", option.None)

  // Act
  let result = hawk.send(payload)

  // Assert
  assert result == Error("Hawk is not initialized")
}

pub fn init_rejects_empty_token_test() {
  // Arrange
  let token = ""

  // Act
  let result = hawk.init(token)

  // Assert
  assert result
    == Error("Integration token length must be at least 1 characters")
}

pub fn init_rejects_token_longer_than_256_characters_test() {
  // Arrange
  let token = string.repeat("a", 257)

  // Act
  let result = hawk.init(token)

  // Assert
  assert result
    == Error("Integration token length must be at most 256 characters")
}
