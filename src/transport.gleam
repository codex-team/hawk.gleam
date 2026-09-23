import event.{type Event}

pub type Transport {
  Transport(url: String)
}

// const default_url = "http://127.0.0.1:8787/"

const default_url = "https://k1.hawk.so/"

const success_status_from = 200

const success_status_until = 300

@external(erlang, "transport_ffi", "configure")
fn configure_ffi(max_sessions: Int) -> Result(Nil, Nil)

@external(erlang, "transport_ffi", "send")
fn send_ffi(url: String, body: String) -> Result(Int, Nil)

@internal
pub fn new() -> Transport {
  Transport(default_url)
}

@internal
pub fn configure(max_sessions: Int) -> Result(Nil, String) {
  case configure_ffi(max_sessions) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("Failed to configure Hawk HTTP client")
  }
}

@internal
pub fn send(transport: Transport, event: Event) -> Result(Nil, String) {
  case send_ffi(transport.url, event.to_json(event)) {
    Ok(status) ->
      case is_success_status(status) {
        True -> Ok(Nil)
        False -> Error("Hawk returned unsuccessful HTTP status")
      }
    Error(_) -> Error("HTTP request failed")
  }
}

fn is_success_status(status: Int) -> Bool {
  status >= success_status_from && status < success_status_until
}
