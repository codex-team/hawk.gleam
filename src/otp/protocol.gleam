import event
import gleam/erlang/process.{type Subject}

pub type WorkerMessage {
  ProcessEvent(event.Event)
}

pub type DispatcherMessage {
  Enqueue(event.EventPayload)
  WorkerOnline(Int, Subject(WorkerMessage))
}
