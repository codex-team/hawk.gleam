# hawk.gleam

[Hawk.so](https://hawk.so/) error catcher for Gleam applications running on the
Erlang target.

> [!NOTE]
> This repository is an initial development version. The package is not yet
> published to Hex.

## Requirements

- Gleam 1.18 or newer
- The Erlang target (CI currently uses Erlang/OTP 29)

## Installation

Until the first Hex release, clone this repository and add it as a local path
dependency:

```toml
[dependencies]
hawk_gleam = { path = "../hawk.gleam" }
```

Adjust the path for your directory layout. After a Hex release, installation
will use:

```sh
gleam add hawk_gleam
```

## Usage

```gleam
import event
import gleam/option
import hawk_gleam as hawk

pub fn main() -> Nil {
  case hawk.init("YOUR_INTEGRATION_TOKEN") {
    Ok(hawk.Initialized) -> Nil
    Ok(hawk.InitializedWithoutLogger(reason)) -> {
      // Manual events can still be sent when logger registration fails.
      echo "Hawk logger handler was not registered: " <> reason
    }
    Error(reason) -> panic as "Failed to initialize Hawk: " <> reason
  }

  let assert Ok(Nil) =
    hawk.send(event.EventPayload(
      title: "Hello from Hawk",
      event_type: option.None,
    ))

  Nil
}
```

Call `hawk.init` once with a Hawk integration token before sending events. It
starts a supervised dispatcher, two HTTP workers, and an OTP Logger handler for
messages at the `error` level and above, including supported crash reports.

`hawk.send` is asynchronous: `Ok(Nil)` only confirms that the event was placed
in the local dispatcher mailbox. It does not confirm delivery to Hawk. Payload
validation and the HTTP request happen in a worker; failures are printed to
standard output with a `[Hawk] [ERROR]` prefix. There are currently no retries,
flush API, or delivery acknowledgement.

### Payload limits

- Integration token: 1-256 characters
- Title: 1-128 characters
- Event type: optional, up to 64 characters

Calling `hawk.init` again is idempotent, but it does not replace the integration
token supplied by the first successful call.

## Development

Download dependencies and run the same checks used by CI:

```sh
gleam deps download
gleam format --check src test
gleam check --target erlang
gleam test --target erlang
gleam docs build
```
