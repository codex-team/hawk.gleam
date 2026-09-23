import event
import gleam/result
import otp/dispatcher
import otp/root_supervisor
import utils/validation

pub type InitStatus {
  Initialized
  InitializedWithoutLogger(String)
}

@external(erlang, "otp_logger_handler", "init_hawk_otp_logger_handler")
fn init_hawk_otp_logger_handler() -> Result(Nil, String)

pub fn init(integration_token: String) -> Result(InitStatus, String) {
  use _ <- result.try(validation.validate_integration_token(integration_token))
  use _ <- result.try(root_supervisor.start(integration_token))
  case init_hawk_otp_logger_handler() {
    Ok(_) -> Ok(Initialized)
    Error(error) -> Ok(InitializedWithoutLogger(error))
  }
}

pub fn send(payload: event.EventPayload) -> Result(Nil, String) {
  dispatcher.enqueue(payload)
}
