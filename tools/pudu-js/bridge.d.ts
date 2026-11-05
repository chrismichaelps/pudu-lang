/** How a call to the program failed. */
export type PuduErrorKind = 'unknown-command' | 'denied' | 'invalid-arguments' | 'failed' | 'internal' | 'transport';

/** A failed call, carrying the program's own explanation. */
export interface PuduError extends Error {
  readonly kind: PuduErrorKind;
  readonly command: string;
  /** Where in the arguments decoding stopped, such as `.items[2].name`. */
  readonly path: string;
}

/** Ordered messages the program sends for one call. */
export interface Channel<T> {
  readonly id: number;
  onmessage: ((message: T) => void) | null;
  onclose: (() => void) | null;
  close(): void;
}

/** One event the program emitted. */
export interface PuduEvent<T> {
  readonly event: string;
  readonly payload: T;
}

export interface PuduBridge {
  invoke<T>(command: string, args?: unknown, options?: { channel?: Channel<unknown> }): Promise<T>;
  listen<T>(event: string, handler: (message: PuduEvent<T>) => void): () => void;
  once<T>(event: string, handler: (message: PuduEvent<T>) => void): () => void;
  emit(event: string, payload?: unknown): Promise<null>;
  readonly Channel: new <T>(onmessage?: (message: T) => void) => Channel<T>;
  readonly PuduError: new (envelope: { kind: PuduErrorKind; message: string; command: string; path?: string }) => PuduError;
  /** The label of the view this page runs in. */
  readonly label: string;
}

declare global {
  interface Window {
    readonly __pudu: PuduBridge;
  }
}
