import event
import gleam/option

pub fn creates_valid_event_test() {
  // Arrange
  let user = event.User("user-42")
  let payload = event.EventPayload("Database unavailable", option.Some("error"))

  // Act
  let result =
    event.create_new_and_valid_event(
      "errors/default",
      "integration-token",
      user,
      payload,
    )

  // Assert
  assert result
    == Ok(event.Event(
      catcher_type: "errors/default",
      integration_token: "integration-token",
      user: user,
      payload: payload,
    ))
}

pub fn rejects_event_with_empty_title_test() {
  // Arrange
  let payload = event.EventPayload("", option.None)

  // Act
  let result =
    event.create_new_and_valid_event(
      "errors/default",
      "integration-token",
      event.User("user-42"),
      payload,
    )

  // Assert
  assert result == Error("Title length must be at least 1 characters")
}

pub fn rejects_event_with_oversized_event_type_test() {
  // Arrange
  let payload =
    event.EventPayload(
      "Database unavailable",
      option.Some(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      ),
    )

  // Act
  let result =
    event.create_new_and_valid_event(
      "errors/default",
      "integration-token",
      event.User("user-42"),
      payload,
    )

  // Assert
  assert result == Error("Event type length must be at most 64 characters")
}

pub fn serializes_event_with_type_to_json_test() {
  // Arrange
  let event =
    event.Event(
      catcher_type: "errors/default",
      integration_token: "integration-token",
      user: event.User("user-42"),
      payload: event.EventPayload("Database unavailable", option.Some("error")),
    )

  // Act
  let json = event.to_json(event)

  // Assert
  assert json
    == "{\"token\":\"integration-token\",\"catcherType\":\"errors/default\",\"payload\":{\"type\":\"error\",\"title\":\"Database unavailable\",\"user\":{\"id\":\"user-42\"}}}"
}

pub fn serializes_event_without_type_to_json_test() {
  // Arrange
  let event =
    event.Event(
      catcher_type: "errors/default",
      integration_token: "integration-token",
      user: event.User("user-42"),
      payload: event.EventPayload("Database unavailable", option.None),
    )

  // Act
  let json = event.to_json(event)

  // Assert
  assert json
    == "{\"token\":\"integration-token\",\"catcherType\":\"errors/default\",\"payload\":{\"title\":\"Database unavailable\",\"user\":{\"id\":\"user-42\"}}}"
}
