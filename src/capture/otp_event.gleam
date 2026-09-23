import event
import gleam/option
import otp/dispatcher
import utils/validation

pub fn capture(title: String, event_type: String) -> Result(Nil, String) {
  let title = validation.truncate_title(title)
  dispatcher.enqueue(event.EventPayload(title, option.Some(event_type)))
}
