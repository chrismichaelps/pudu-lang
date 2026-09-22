# Concurrency

Pudu has two tools for work that happens alongside other work: asynchronous functions joined by structured scopes, and host workers that run in parallel and talk over channels.

## Async functions

An `async fn` returns a task. `.await` runs the task and gives its value, and it is allowed only inside another `async fn`. A program that awaits declares `main` itself `async`:

```pudu
module Tasks

import Std.Io as Io

async fn scoreFor(name: Str) -> Result[Int, Str] {
  if name.isEmpty() { Err("no name") } else { Ok(name.length() * 10) }
}

export async fn main() -> Result[Int, Str] {
  let first = scoreFor("ada").await
  let second = scoreFor("grace").await
  let _written = Io.writeLine("total {first + second}")
  Ok(0)
}
```

When an async function's declared result is `Result[T, E]`, awaiting it gives the `T`. A failure leaves the enclosing function through its own `Result`, so there is no error to unwrap at each `await`.

## Structured scopes

`async with scope { ... }` opens a region that the tasks started inside it cannot outlive. A child that is never awaited is joined when the scope ends, and leaving the scope early — by `return` or `break` — joins the children first. No task is ever left running after the code that started it has finished.

> The interpreter runs async tasks deterministically, one after another. Cancellation and parallel execution of async tasks are not implemented yet.

## Workers and channels

For work that should run in parallel, `Std.Concurrent` starts host workers and joins them, and `Std.Channel` carries values between them. A channel has a fixed capacity, so a sender that outpaces its receiver waits rather than filling memory. `Std.Sync` provides mutexes and cells for state that workers share.

| Module | Provides |
| --- | --- |
| [Std.Concurrent](/module/Std.Concurrent) | starting workers, joining them, bounded parallel maps |
| [Std.Channel](/module/Std.Channel) | bounded channels between workers |
| [Std.Sync](/module/Std.Sync) | mutexes and shared cells |

Worker ownership by lexical scopes and cancellation that propagates between workers are not complete yet; join every worker a program starts.
