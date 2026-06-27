const path = require("path");
const { readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");
const builder = readTextFile(path.join(root, "scripts", "ui", "screens", "result_screen_view_model_builder.gd"));

if (!builder.includes("RunDiagnosticServiceScript.build_diagnostic(run_state)")) {
  throw new Error("ResultScreenViewModelBuilder must call build_diagnostic with run_state only.");
}

if (/build_diagnostic\s*\(\s*state\s*,/.test(builder)) {
  throw new Error("ResultScreenViewModelBuilder must not pass state to build_diagnostic.");
}

console.log("Result screen diagnostic call verified.");
