import event
import gleam/erlang/atom
import gleam/erlang/process.{type Name, type Subject}
import gleam/list
import gleam/otp/actor
import gleam/otp/factory_supervisor
import gleam/otp/supervision
import gleam/result
import otp/http_worker
import otp/protocol
import otp/snapshot
import transport
import utils/logger
import utils/validation

const default_catcher_type = "errors/default"

const initialiser_timeout_ms = 5000

type Worker {
  Worker(id: Int, subject: Subject(protocol.WorkerMessage))
}

type State {
  State(
    integration_token: String,
    default_user: event.User,
    transport: transport.Transport,
    workers: List(Worker),
  )
}

@external(erlang, "gleam_erlang_ffi", "identity")
fn atom_to_name(atom: atom.Atom) -> Name(protocol.DispatcherMessage)

fn name() -> Name(protocol.DispatcherMessage) {
  atom.create("hawk_gleam_dispatcher")
  |> atom_to_name
}

@internal
pub fn is_running() -> Bool {
  case process.named(name()) {
    Ok(_) -> True
    Error(_) -> False
  }
}

@internal
pub fn enqueue(payload: event.EventPayload) -> Result(Nil, String) {
  case process.named(name()) {
    Error(_) -> Error("Hawk is not initialized")
    Ok(_) -> {
      actor.send(process.named_subject(name()), protocol.Enqueue(payload))
      Ok(Nil)
    }
  }
}

@internal
pub fn supervised(
  integration_token: String,
  worker_factory_name: Name(
    factory_supervisor.Message(
      http_worker.StartArgument,
      Subject(protocol.WorkerMessage),
    ),
  ),
) {
  supervision.worker(fn() {
    actor.new_with_initialiser(initialiser_timeout_ms, fn(dispatcher) {
      let restored = snapshot.load_or_init()
      let factory = factory_supervisor.get_by_name(worker_factory_name)

      use _ <- result.try(validation.validate_catcher_type(default_catcher_type))
      use _ <- result.try(transport.configure(http_worker.count))

      use workers <- result.try(
        start_workers(factory, dispatcher, restored.transport, 1, []),
      )

      Ok(
        actor.initialised(State(
          integration_token: integration_token,
          default_user: restored.default_user,
          transport: restored.transport,
          workers: workers,
        )),
      )
    })
    |> actor.named(name())
    |> actor.on_message(handle_message)
    |> actor.start
  })
}

fn start_workers(
  factory,
  dispatcher: Subject(protocol.DispatcherMessage),
  worker_transport: transport.Transport,
  id: Int,
  workers: List(Worker),
) -> Result(List(Worker), String) {
  case id > http_worker.count {
    True -> Ok(list.reverse(workers))
    False -> {
      use subject <- result.try(start_worker(
        factory,
        id,
        dispatcher,
        worker_transport,
      ))
      start_workers(factory, dispatcher, worker_transport, id + 1, [
        Worker(id, subject),
        ..workers
      ])
    }
  }
}

fn start_worker(
  factory,
  id: Int,
  dispatcher: Subject(protocol.DispatcherMessage),
  worker_transport: transport.Transport,
) -> Result(Subject(protocol.WorkerMessage), String) {
  case
    factory_supervisor.start_child(
      factory,
      http_worker.StartArgument(id, dispatcher, worker_transport),
    )
  {
    Ok(worker) -> Ok(worker.data)
    Error(_) -> Error("Failed to start HTTP worker")
  }
}

fn handle_message(
  state: State,
  message: protocol.DispatcherMessage,
) -> actor.Next(State, protocol.DispatcherMessage) {
  case message {
    protocol.Enqueue(payload) -> handle_enqueue(state, payload)
    protocol.WorkerOnline(id, subject) ->
      actor.continue(
        State(
          ..state,
          workers: list.map(state.workers, fn(worker) {
            case worker.id == id {
              True -> Worker(id, subject)
              False -> worker
            }
          }),
        ),
      )
  }
}

fn handle_enqueue(
  state: State,
  payload: event.EventPayload,
) -> actor.Next(State, protocol.DispatcherMessage) {
  case
    event.create_new_and_valid_event(
      default_catcher_type,
      state.integration_token,
      state.default_user,
      payload,
    )
  {
    Error(error) -> {
      logger.event_not_sent(error)
      actor.continue(state)
    }
    Ok(event) ->
      case state.workers {
        [] -> actor.continue(state)
        [worker, ..rest] -> {
          actor.send(worker.subject, protocol.ProcessEvent(event))
          actor.continue(State(..state, workers: list.append(rest, [worker])))
        }
      }
  }
}
