const { window, workspace } = require("vscode");
const { LanguageClient, TransportKind } = require("vscode-languageclient/node");

let client;

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

  const configured = workspace.getConfiguration("pudu").get("serverPath") || "pudu";
  const server = {
    command: configured,
    args: ["lsp"],
    transport: TransportKind.stdio,
  };

  client = new LanguageClient(
    "pudu",
    "Pudu",
    { run: server, debug: server },
    {
      documentSelector: [{ scheme: "file", language: "pudu" }],
      synchronize: { fileEvents: workspace.createFileSystemWatcher("**/*.pudu") },
    }
  );

  // The client is what is disposable. `start` answers with a promise, and
  // pushing that instead leaves nothing registered to dispose — the editor then
  // has no way to stop the server, and reports that stopping it timed out.
  context.subscriptions.push(client);

  try {
    await client.start();
  } catch (failure) {
    client = undefined;
    window.showErrorMessage(
      `Pudu: could not start \`${configured} lsp\`. ` +
        "Set `pudu.serverPath` to the compiler, or put it on your PATH. " +
        String(failure)
    );
  }
}

async function deactivate() {
  if (!client) {
    return;
  }
  const stopping = client;
  client = undefined;
  await stopping.stop();
}

module.exports = { activate, deactivate };
