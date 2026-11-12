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

/** What a window is doing, as `window.state()` answers and `pudu:window-state` events carry. */
export interface PuduWindowState {
  readonly minimized: boolean;
  readonly maximized: boolean;
  readonly fullscreen: boolean;
  readonly visible: boolean;
  readonly focused: boolean;
  /** Device pixels per point, in thousandths. */
  readonly scale: number;
  readonly theme: 'light' | 'dark';
}

/** The page's own window. Each action needs a capability granting `window:<action>`. */
export interface PuduWindow {
  minimize(): Promise<null>;
  unminimize(): Promise<null>;
  maximize(): Promise<null>;
  unmaximize(): Promise<null>;
  toggleMaximize(): Promise<null>;
  show(): Promise<null>;
  hide(): Promise<null>;
  focus(): Promise<null>;
  center(): Promise<null>;
  close(): Promise<null>;
  setTitle(title: string): Promise<null>;
  setSize(width: number, height: number): Promise<null>;
  setMinSize(width: number, height: number): Promise<null>;
  setMaxSize(width: number, height: number): Promise<null>;
  setPosition(x: number, y: number): Promise<null>;
  setFullscreen(wanted: boolean): Promise<null>;
  setAlwaysOnTop(wanted: boolean): Promise<null>;
  setDecorations(wanted: boolean): Promise<null>;
  setResizable(wanted: boolean): Promise<null>;
  setClosable(wanted: boolean): Promise<null>;
  setMinimizable(wanted: boolean): Promise<null>;
  setMaximizable(wanted: boolean): Promise<null>;
  setContentProtected(wanted: boolean): Promise<null>;
  setTitleBar(style: 'visible' | 'transparent' | 'overlay'): Promise<null>;
  requestAttention(critical?: boolean): Promise<null>;
  setBadge(label: string | null): Promise<null>;
  /** The last observed backend snapshot; also requests a native state refresh. */
  state(): Promise<PuduWindowState>;
}

/** A file drop onto the page, as `pudu:drop` events carry. */
export interface PuduDrop {
  readonly phase: 'enter' | 'over' | 'drop' | 'leave';
  readonly x: number;
  readonly y: number;
  readonly paths: string[];
}

export interface PuduBridge {
  invoke<T>(command: string, args?: unknown, options?: { channel?: { readonly id: number } }): Promise<T>;
  listen<T>(event: string, handler: (message: PuduEvent<T>) => void): () => void;
  once<T>(event: string, handler: (message: PuduEvent<T>) => void): () => void;
  emit(event: string, payload?: unknown): Promise<null>;
  readonly Channel: new <T>(onmessage?: (message: T) => void) => Channel<T>;
  readonly PuduError: new (envelope: { kind: PuduErrorKind; message: string; command: string; path?: string }) => PuduError;
  /** The label of the view this page runs in. */
  readonly label: string;
  /** The window this page runs in. */
  readonly window: PuduWindow;
}

declare global {
  interface Window {
    readonly __pudu: PuduBridge;
  }
}
