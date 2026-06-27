const fs = require("fs");

function stripBom(text) {
  return text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
}

function readJsonFile(filePath) {
  return JSON.parse(readTextFile(filePath));
}

function readTextFile(filePath) {
  return stripBom(fs.readFileSync(filePath, "utf8"));
}

function writeJsonFile(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, "\t")}\n`, "utf8");
}

module.exports = {
  readJsonFile,
  readTextFile,
  stripBom,
  writeJsonFile,
};
