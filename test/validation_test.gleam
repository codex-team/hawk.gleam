import gleam/option
import gleam/string
import utils/validation

pub fn accepts_integration_token_boundaries_test() {
  // Arrange
  let minimum_token = "a"
  let maximum_token = string.repeat("a", 256)

  // Act
  let minimum_result = validation.validate_integration_token(minimum_token)
  let maximum_result = validation.validate_integration_token(maximum_token)

  // Assert
  assert minimum_result == Ok(Nil)
  assert maximum_result == Ok(Nil)
}

pub fn validates_supported_catcher_type_test() {
  // Arrange
  let supported = "errors/default"
  let unsupported = "logs/default"

  // Act
  let supported_result = validation.validate_catcher_type(supported)
  let unsupported_result = validation.validate_catcher_type(unsupported)

  // Assert
  assert supported_result == Ok(Nil)
  assert unsupported_result == Error("Catcher type must be 'errors/default'")
}

pub fn validates_optional_event_type_test() {
  // Arrange
  let missing_type = option.None
  let maximum_type = option.Some(string.repeat("a", 64))
  let oversized_type = option.Some(string.repeat("a", 65))

  // Act
  let missing_result = validation.validate_event_type(missing_type)
  let maximum_result = validation.validate_event_type(maximum_type)
  let oversized_result = validation.validate_event_type(oversized_type)

  // Assert
  assert missing_result == Ok(Nil)
  assert maximum_result == Ok(Nil)
  assert oversized_result
    == Error("Event type length must be at most 64 characters")
}

pub fn truncates_title_to_128_characters_test() {
  // Arrange
  let title = string.repeat("a", 129)
  let expected = string.repeat("a", 128)

  // Act
  let result = validation.truncate_title(title)

  // Assert
  assert result == expected
}

pub fn leaves_valid_title_unchanged_test() {
  // Arrange
  let title = "Database unavailable"

  // Act
  let result = validation.truncate_title(title)

  // Assert
  assert result == title
}

pub fn rejects_empty_user_id_test() {
  // Arrange
  let user_id = ""

  // Act
  let result = validation.validate_user_id(user_id)

  // Assert
  assert result == Error("User ID length must be at least 1 characters")
}
