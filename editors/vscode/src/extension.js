const { commands, window, workspace } = require("vscode");
const { LanguageClient, TransportKind } = require("vscode-languageclient/node");

let client;
let output;

/**
 * Start the server and hand it every `.pudu` document.
 *
 * The server is the compiler itself — `pudu lsp` — rather than a separate
 * analyser, so the editor and the command line can never disagree about what a
 * program means.
 */
async function activate(context) {
  // A second activation would leave the first server with nothing to stop it.
  if (client) {
    return;
  }

  // One channel for the whole session, so a restart appends to what the
  // reader was already looking at instead of opening a second panel.
  output = window.createOutputChannel("Pudu");
  context.subscriptions.push(output);

  context.subscriptions.push(
    commands.registerCommand("pudu.restartServer", restart),
    // A new compiler path names a different server; the running one is stale.
    workspace.onDidChangeConfiguration(change => {
      if (change.affectsConfiguration("pudu.serverPath")) {
        restart();
      }
    }),
    { dispose: () => stop() }
  );

  await start();
}

async function start() {
  const configured = workspace.getConfiguration("pudu").get("serverPath") || "pudu";
  const server = {
    command: configured,
    args: ["lsp"],
    transport: TransportKind.stdio,
  };

  const candidate = new LanguageClient(
    "pudu",
    "Pudu",
    { run: server, debug: server },
    {
      documentSelector: [{ scheme: "file", language: "pudu" }],
      synchronize: { fileEvents: workspace.createFileSystemWatcher("**/*.pudu") },
      outputChannel: output,
    }
  );

  try {
    await candidate.start();
    client = candidate;
  } catch (failure) {
    window.showErrorMessage(
      `Pudu: could not start \`${configured} lsp\`. ` +
        "Set `pudu.serverPath` to the compiler, or put it on your PATH. " +
        String(failure)
    );
  }
}

async function stop() {
  if (!client) {
    return;
  }
  const stopping = client;
  client = undefined;
  try {
    await stopping.stop();
  } catch {
    // A server that already exited has nothing left to stop.
  }
}

/**
 * Stop the running server and start the configured one: what a reader wants
 * after rebuilding the compiler, without reloading the window.
 */
async function restart() {
  await stop();
  await start();
}

async function deactivate() {
  await stop();
}

module.exports = { activate, deactivate };
