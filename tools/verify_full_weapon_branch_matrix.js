const {
  EXPECTED_COUNTS,
  MATRIX_JSON,
  MATRIX_TEXT,
  buildMatrix,
  validateStaticMatrix,
  writeMatrixReports,
} = require("./full_weapon_branch_matrix");

function main() {
  const result = buildMatrix();
  const errors = validateStaticMatrix(result);
  writeMatrixReports(result, errors);

  if (errors.length) {
    for (const error of errors) {
      console.error(`ERROR ${error}`);
    }
    console.error(`Full weapon branch matrix failed. cases=${result.cases.length} expected=${EXPECTED_COUNTS.cases} report=${MATRIX_TEXT}`);
    process.exitCode = 1;
    return;
  }

  console.log(`Full weapon branch matrix verified. cases=${result.cases.length} expected=${EXPECTED_COUNTS.cases} report=${MATRIX_JSON}`);
}

main();
