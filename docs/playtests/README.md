# Play-test reports

The architect writes one report for each plan: `NNNN-report.md`.

A report has these sections:

1. The commit that the architect tested.
2. The scenarios and the screen sizes that the architect ran.
3. The defects. Each defect has an ID (`D-NNNN-01`), the steps to see it, the expected result, the actual result, and a screenshot.
4. The audit of the code against the requirements of the plan.

The builder corrects each defect and adds a play-test step that finds it.
