// Why a request to the playground's server did not produce an answer.

export const FAILURE = Object.freeze({
  // The caller withdrew the request because a newer one replaced it.
  cancelled: "cancelled",
  // The request ran past its deadline.
  timedOut: "timedOut",
  // The server could not be reached at all.
  offline: "offline",
  // The server answered with something that is not the JSON it promises.
  unreadable: "unreadable",
});

export class RequestFailure extends Error {
  constructor(kind, status = 0) {
    super(`playground request failed: ${kind}${status ? ` (${status})` : ""}`);
    this.name = "RequestFailure";
    this.kind = kind;
    this.status = status;
  }

  get cancelled() {
    return this.kind === FAILURE.cancelled;
  }
}
