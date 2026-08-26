const { workspace } = require("vscode");
const { LanguageClient, TransportKind } = require("vscode-languageclient/node");

let client;

/**
 * Start the server and hand it every `.pudu` document.
 *
 * The server is the compiler itself — `pudu lsp` — rather than a separate
 * analyser, so the editor and the command line can never disagree about what a
 * program means.
 */
function activate(context) {
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

  context.subscriptions.push(client.start());
}

function deactivate() {
  return client ? client.stop() : undefined;
}

module.exports = { activate, deactivate };
