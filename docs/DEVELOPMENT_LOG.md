# Employee Management System — Development Log

This log records development work for the Salesforce DX project. Dates use the user's local timezone, Asia/Calcutta.

## 2026-11-23 — Training assignment Apex test

### Project review

- Connected to the `Employee-Management-System` folder open in VS Code at `OneDrive/Desktop/employee manegment/Employee-Management-System`.
- Inspected the project files and structure before editing. The project uses Salesforce DX (`sfdx-project.json`, package directory `force-app`, API version 68.0), Apex classes, one Lightning Web Component (`trainingAssignmentForm`), its Jest test, helper scripts, and a scratch-org definition.
- The focused feature consists of `TrainingAssignmentController`, `TrainingAssignmentControllerTest`, and `trainingAssignmentForm`.
- No `AGENTS.md` project instructions or `.git` directory were present. The local source tree does not contain custom-object metadata for the Department, Employee, Training, or Employee Training records; those definitions are supplied by the connected Salesforce org.
- The separate TDS UK apprenticeship project was not accessed or changed.

### File changes

1. `force-app/main/default/classes/TrainingAssignmentControllerTest.cls`
   - Added `Phone__c = '555-010-1001'` to the test Employee created in `@TestSetup`.
   - Reason: Salesforce reported `Phone__c` as a required field when inserting the test Employee. A fixed dummy number makes the test record satisfy the org's schema without depending on real employee data.

2. `docs/DEVELOPMENT_LOG.md`
   - Created this chronological record of the review, code change, errors, deployment, test outcomes, and learning concepts.

No controller, Lightning Web Component, or metadata XML source was changed in this task.

### Issues, fixes, and verification history

1. Running the Apex test from this chat's shell failed before the Salesforce command could start because the CLI could not write its log under the user's `.sf` directory (`EPERM`). Switched to the already-open VS Code integrated terminal; this avoided changing Salesforce CLI settings or credentials.
2. First Apex run reported that `TrainingAssignmentControllerTest` was not yet present in the target org. Deployed the test class and its metadata XML to the `mydevorg` alias. Deployment succeeded (one component deployed).
3. The first actual test execution then ran the shared test setup but failed because `Employee__c.Phone__c` is required. Queried the org schema to confirm required Employee fields; the other required fields were already supplied in the test data.
4. Added the dummy `Phone__c` value locally. An immediate rerun still failed with the same error because Salesforce was executing the previously deployed version. Deployed the updated class and metadata; the deployment succeeded and reported both files as changed in the org.
5. Reran `TrainingAssignmentControllerTest` against `mydevorg`. Result: **Passed**; 4 test methods passed, 0 failed, 0 skipped. The CLI summary counted 5 executions including the shared `@TestSetup` method. The individual passing methods were:
   - `testSuccessfulAssignment`
   - `testDuplicateAssignment`
   - `testDifferentTrainingAssignment`
   - `testMissingInput`

### Deployment record

- Target alias: `mydevorg` (the default org selected in VS Code).
- First deployment: `TrainingAssignmentControllerTest` class and metadata; successful.
- Updated deployment after adding the required phone: class and metadata XML; successful (`status: Succeeded`, no component errors, no warnings).
- The controller itself was not changed or deployed in this task.

### Learning concepts

- **Salesforce DX source and org are separate:** changing a local Apex file does not update Salesforce until that metadata is deployed.
- **`@TestSetup` supplies repeatable data:** Salesforce creates the setup records for the test methods, so tests can run without depending on existing business records.
- **Required fields come from the org schema:** every test record must provide required values, even when a field is not directly used in the assertion.
- **Test methods validate behavior:** this class verifies that an assignment is created with the expected values, duplicate assignments are rejected, a different training can be assigned, and missing IDs produce handled errors.
- **Test run count includes setup:** the final summary listed 5 executions because it includes four test methods and the shared setup method; the four behavior tests all passed.

### Follow-up

- The full technical documentation and manager-ready project explanation remain planned for overall project completion. This log is maintained incrementally so the final documentation can use verified implementation and test history.

## 2026-11-23 — Apex code coverage review

- Followed the immediate next step recorded in the referenced learning chat: review actual Apex coverage after the test passes.
- Command used: `sf apex run test --class-names TrainingAssignmentControllerTest --target-org mydevorg --code-coverage --result-format human --wait 10`.
- Result: test run **Passed**; all 4 behavior test methods passed, with 0 failures and 0 skipped.
- `TrainingAssignmentController` coverage: **100%**, with no uncovered lines reported.
- Org-wide Apex coverage: **5%**. This is a separate org-level measure and does not change the controller's 100% class coverage result. Broader project tests will be needed to improve org-wide coverage as additional Apex features are completed.
- Learning concept: class-level coverage tells us how much of this controller's code ran in these tests; org-wide coverage measures Apex coverage across the connected org. Coverage shows which lines executed, while the assertions determine whether behavior was correct.
- Roadmap: after this coverage review, the next planned project phase is to strengthen duplicate prevention and input/business-rule validations.

## 2026-11-23 — Assignment validation and duplicate prevention

### Review and design

- Reviewed the current controller and test class, then checked field definitions in `mydevorg` before selecting business rules.
- `Employee__c.Employment_Status__c` offers Active, Inactive, On Leave, Resigned, and Terminated. `Training__c.Active__c` is a Boolean field.
- Applied the rule that only an employee with status `Active` may receive a training and the training program itself must have `Active__c = true`.
- Salesforce's official Apex locking documentation describes `FOR UPDATE` as a way to lock records while application logic runs to prevent race conditions. The controller now locks the selected employee before checking for an existing employee/training pair. This serializes calls that go through this controller for the same employee; it does not replace a database unique constraint for writes made through other paths.

### File changes

1. `force-app/main/default/classes/TrainingAssignmentController.cls`
   - Added a `FOR UPDATE` employee query before the duplicate check.
   - Added a handled error when the employee record cannot be found or is not Active.
   - Added a training lookup and handled errors when the training cannot be found or is inactive.
   - Kept the existing pair-based duplicate check and the default-to-today behavior for a blank assigned date.
2. `force-app/main/default/classes/TrainingAssignmentControllerTest.cls`
   - Strengthened the duplicate test to verify exactly one assignment remains.
   - Expanded input validation coverage to reject a User ID used as an Employee or Training ID.
   - Added tests for inactive employees, inactive trainings, and a null assigned date defaulting to today.
3. `docs/DEVELOPMENT_LOG.md`
   - Appended this phase's design decisions, code changes, deployment/test outcomes, and learning notes.

### Deployment and verification

- Deployed the `classes` directory to `mydevorg`, including `TrainingAssignmentController` and `TrainingAssignmentControllerTest` plus their metadata XML files. Salesforce reported the four Apex class components as Changed and no deployment warnings.
- Command: `sf apex run test --class-names TrainingAssignmentControllerTest --target-org mydevorg --code-coverage --result-format human --wait 10`.
- Result: **Passed**; 7 behavior test methods passed, 0 failed, 0 skipped. Salesforce's summary counted 8 executions including `@TestSetup`.
- Passing methods: `testSuccessfulAssignment`, `testDuplicateAssignment`, `testDifferentTrainingAssignment`, `testMissingInput`, `testInactiveEmployeeRejected`, `testInactiveTrainingRejected`, and `testNullAssignedDateDefaultsToToday`.
- `TrainingAssignmentController` coverage remains **100%**, with no uncovered lines reported. Org-wide Apex coverage reported **9%** in this run (previously 5%).

### Learning concepts and limits

- A server-side check protects the rule even if a caller bypasses the Lightning form.
- A row lock temporarily prevents competing transactions from running the same employee-specific validation simultaneously. The test suite verifies the normal duplicate path but does not simulate concurrent transactions.
- Class coverage measures executed lines; assertions check expected behavior. Neither metric alone proves that every business edge case is covered.
- A unique database constraint on the Employee/Training pair would provide protection for all insert paths. The project does not include local `Employee_Training__c` metadata, so that schema-level change was not made as part of this code-only phase.

### Next roadmap item

- The validation/duplicate-prevention phase is complete for the selected rules. The next item in the referenced roadmap is to improve the Lightning Web Component user experience.

## 2026-11-23 — Training form usability improvements

### File changes

1. `force-app/main/default/lwc/trainingAssignmentForm/trainingAssignmentForm.js`
   - Changed the default date calculation to use the user's local calendar date instead of UTC, avoiding a date that can appear one day early or late near timezone boundaries.
   - Added record-picker filters so employees must have Active status and training programs must have `Active__c = true`. These match the server-side rules added in the previous phase.
   - Added an early guard against submitting while required selections are missing or another submission is already running.
   - Added a changing button label during submission, reset the date to today after success, shortened the success message, and improved fallback error display.
2. `force-app/main/default/lwc/trainingAssignmentForm/trainingAssignmentForm.html`
   - Added a short instruction above the form.
   - Added a small accessible spinner while assigning and disabled both pickers and the date field during submission.
   - Connected the active-record filters and dynamic button label to the component.
3. `docs/DEVELOPMENT_LOG.md`
   - Added this record of the usability changes and verification.

### Deployment and verification

- Deployed the `trainingAssignmentForm` bundle to `mydevorg`. Salesforce reported the bundle files as Changed and returned no deployment warnings.
- JavaScript syntax check passed using Node's module parser.
- The LWC Jest test file remains the generated TODO placeholder. The project has no local `node_modules` directory, so the Jest suite could not be run without installing dependencies; no dependencies were installed in this phase.
- A first attempt to feed JavaScript to Node using shell `<` redirection was rejected by PowerShell; reran the syntax check using a PowerShell pipeline successfully. This was a shell-command issue, not an application defect.

### Learning concepts

- A local date input should be initialized from local calendar fields; `toISOString()` converts to UTC and can shift the visible day.
- Client-side record-picker filters make valid choices easier to find. The Apex checks remain the final safeguard if another caller bypasses the form.
- A loading spinner, changing button label, and disabled inputs tell the user that their request is being processed and reduce accidental repeat submissions.
- Salesforce's [record picker component reference](https://developer.salesforce.com/docs/platform/lightning-component-reference/guide/lightning-record-picker) documents the `filter` criteria object used for filtering search results.

### Follow-up

- The Lightning Web Component bundle is deployed, but its Jest test file still needs real component tests when the project's npm development dependencies are installed.
- The next item in the original project roadmap is to build out employee and training management features.

## 2026-11-23 — Employee training progress

### Project and org review

- Rechecked the complete Salesforce DX source tree before this change. The source had the training-assignment controller/form, but no employee training-list controller or employee-facing training component.
- Read the project overview, DX configuration, npm scripts, existing controller/test classes, assignment form and the accumulated development log.
- Queried the connected `mydevorg` schema through the already-open VS Code Salesforce terminal. Confirmed `Employee__c.Salesforce_user__c` is an optional lookup to `User`; `Employee_Training__c.Employee__c` and `Training__c` are required lookups; and status, assigned date, completion date and score are available fields. Status options include Assigned and In Progress, with Completed used by the new feature.
- The separate TDS UK apprenticeship project was not opened or changed.

### File changes

1. `force-app/main/default/classes/MyTrainingController.cls` and its metadata XML
   - Added `getMyTrainings()`, which resolves the logged-in Salesforce user to exactly one Employee record and returns only that employee's training assignments.
   - Added `updateMyTraining()`, which accepts only In Progress or Completed, requires a completion date for Completed, and checks that the assignment belongs to the current employee.
   - The update writes only `Training_Status__c` and `Completion_Date__c`. It never accepts or writes `Score__c`.
   - Added handled errors for a missing assignment ID, missing employee mapping, duplicate employee mappings, unsupported statuses, missing completion date and an assignment owned by someone else.
2. `force-app/main/default/classes/MyTrainingControllerTest.cls` and its metadata XML
   - Added isolated test records for the current employee, an unlinked employee, a training and their assignments.
   - Added tests for own-record filtering, In Progress updates, Completed updates and date requirement, score preservation, another employee's record, unsupported/missing inputs, and missing/ambiguous user-to-employee mappings.
3. `force-app/main/default/lwc/myTraining/myTraining.js`, `.html` and `.js-meta.xml`
   - Added an exposed Lightning component for employees to see training name, assignment date, current status and completion date.
   - Added status/date controls, a per-assignment save action, loading/error/empty states, success/error messages and a refresh after successful saves.
   - The score is not shown or submitted by this employee component.
4. `docs/DEVELOPMENT_LOG.md`
   - Recorded this implementation, test/deployment trail, field checks and learning notes.

### Deployment and test results

- First deployed the new Apex classes and `myTraining` LWC bundle to the VS Code default org alias `mydevorg`. Salesforce reported successful deployment with no component errors or warnings.
- Initial test run: both `TrainingAssignmentControllerTest` and `MyTrainingControllerTest` passed; 15 tests, 0 failures. Existing assignment-controller coverage was 100%; new controller coverage was 88% because missing-ID and duplicate-user-mapping error branches were not yet exercised.
- Added tests for those two branches, redeployed the classes, and reran both classes with coverage.
- Final test run: **Passed**, 16 tests, 0 failures, 0 skipped. `TrainingAssignmentController` coverage: **100%**. `MyTrainingController` coverage: **100%**. Org-wide coverage reported 17%.
- Salesforce CLI printed an informational warning that array arguments should use the newer `--array-flag` format. The selected classes ran correctly and the warning did not affect deployment or test results.
- A local Node syntax-only check was attempted for the LWC JavaScript, but plain Node does not understand Salesforce's `@wire` decorator and rejected that syntax. This is not an LWC compile failure: Salesforce accepted and deployed the complete component bundle successfully. No local Jest run was available because this project has no `node_modules` directory.

### Learning concepts and operational follow-up

- A Salesforce user is linked to an employee record through a lookup field; the server should resolve this relationship from `UserInfo.getUserId()` instead of trusting an employee ID supplied by the browser.
- `with sharing` plus an explicit `Employee__c` filter limits the returned assignments to the current user's employee record. The update repeats the ownership filter, so changing a record ID in the browser does not grant access to another employee's assignment.
- The Apex method accepts only the fields employees are meant to change. Excluding score from the request and update protects it from this employee workflow.
- Apex tests run in isolated transactions with their own records. Coverage increased to 100% after the tests exercised the defensive input and mapping cases; assertions also verified the score remained unchanged.
- The LWC is deployed and available to add to a Lightning App, Home or Record page. It has not yet been placed on a page or verified with a non-admin employee login. A real employee account also needs `Employee__c.Salesforce_user__c` linked to that user's Salesforce record and `MyTrainingController` Apex class access. No profile or permission-set assignments were changed. The project's custom-object metadata and access configuration are not present in this source tree, so sharing, field permissions and class access for employee profiles still need an org-level review before end-user rollout.
- The full project technical documentation and manager-ready explanation remain planned for overall project completion.

## 2026-11-23 — Grouped training dashboard and training details

### Requested behavior

- The employee page originally showed every training assignment in one long list. The user requested three separate status sections—Completed, Assigned and In Progress—and details for each training.
- Preserved the existing access rule: employees can change status and completion date, but cannot edit scores. Score is shown read-only because the approved project behavior allows employees to view it.

### File changes

1. `force-app/main/default/classes/MyTrainingController.cls`
   - Expanded the employee-only query to return training code, category, duration, whether the program is active, assignment date, current status, completion date and score, along with the training name.
   - The query still filters by the Employee record linked to the signed-in user. The update method still writes only status and completion date.
2. `force-app/main/default/classes/MyTrainingControllerTest.cls`
   - Extended the ownership/filtering test to assert the returned training code, category, duration, active state and read-only score.
3. `force-app/main/default/lwc/myTraining/myTraining.js`
   - Added status groupings in the requested order: Completed, Assigned, In Progress.
   - Added counts, empty-category state, formatted labels for absent details, and a save-in-progress state.
4. `force-app/main/default/lwc/myTraining/myTraining.html`
   - Replaced the single long list with three labeled sections and a count per section.
   - Added training code, category, duration, program availability, assigned date and score display to every assignment card. The score is labeled read-only; the existing status and completion-date controls remain editable.
5. `docs/DEVELOPMENT_LOG.md`
   - Recorded the requested grouping, expanded fields, validation and deployment.

### Deployment and verification

- Deployed the updated Apex classes and `myTraining` Lightning Web Component to `mydevorg`. Salesforce completed the deployment successfully with no component errors or warnings.
- Reran `TrainingAssignmentControllerTest` and `MyTrainingControllerTest`: **16 tests passed, 0 failed, 0 skipped**. `TrainingAssignmentController` and `MyTrainingController` both reported **100%** class coverage. Org-wide coverage remained 17%.
- Refreshed the activated My Trainings app page in Salesforce and confirmed the live screen displays the three groups and counts (Completed: 2, Assigned: 2, In Progress: 0), with training details in each assignment card. The empty In Progress section is expected until an assignment is moved into that status.
- Salesforce test records showed values for code, category, duration, active state and score; assignments without a score display “Not recorded.” No score-edit control is present.
- The page itself was previously created and activated by the user; this phase updated its deployed component and did not change employee records or page activation settings.
- Local LWC Jest tests remain unavailable because the project has no `node_modules` directory. Salesforce successfully compiled and deployed the updated component bundle.

### Learning notes

- Grouping the rows in the Lightning Web Component keeps server-side data retrieval simple; each returned assignment is filtered into a status section for display.
- Counts and empty states help distinguish “no trainings in this category” from a loading or query failure.
- Displaying a score does not require making it editable. The Apex update accepts only status and completion date, and the page exposes score as text.
- A successful Apex test validates the server rules; refreshing the deployed page validates that Lightning receives the expected fields and renders the groups in the actual org.

## 2026-11-23 — Prevent future completion dates

### Requested behavior and implementation

- The user requested that completed training assignments reject a completion date later than today.
- `force-app/main/default/classes/MyTrainingController.cls`: added an Apex validation that throws a handled message when a Completed assignment has a completion date after `Date.today()`. This server-side check applies even if a client bypasses the date picker.
- `force-app/main/default/classes/MyTrainingControllerTest.cls`: extended the invalid-input test to assert that a future date is rejected.
- `force-app/main/default/lwc/myTraining/myTraining.js`: added a local-calendar today value for the component's date limit.
- `force-app/main/default/lwc/myTraining/myTraining.html`: set the completion-date input's `max` value to today, helping users avoid selecting a future date.
- `docs/DEVELOPMENT_LOG.md`: recorded the change and results.

### Deployment and verification

- Deployed the updated Apex classes and `myTraining` component to `mydevorg`; Salesforce returned success with no component errors or warnings.
- Reran `TrainingAssignmentControllerTest` and `MyTrainingControllerTest`: **16 tests passed, 0 failed, 0 skipped**. Both controller classes reported **100%** coverage. Org-wide coverage reported 18%.

### Learning note

- A browser date limit improves the form, while Apex validation is the final safeguard. The rule is checked against the Salesforce server's current date, so a future date cannot be saved by another caller either.

## 2026-11-23 — HR training results and score management

### Requested behavior

- Added a dedicated HR workspace to review employee training results and edit scores.
- The page filters assignments by employee, training program and status, and shows employee/training details, assignment/completion dates and current status.
- HR scores can be set from 0 through 100 or cleared. Employees continue to use the separate My Trainings page; it does not expose a score-edit control.

### File changes

1. `force-app/main/default/classes/HRTrainingController.cls` and its metadata XML
   - Added an Apex controller that requires the `Manage_Training_Scores` custom permission before it can return or update records.
   - Added filtered assignment retrieval with an allowed-status check and a 200-row cap to keep the page responsive.
   - Added a bulk score update method that checks every score, rejects missing/duplicate assignment IDs, locks target rows during update and writes only `Score__c`. A blank score can clear the value; status and completion date are not changed by this method.
2. `force-app/main/default/classes/HRTrainingControllerTest.cls` and its metadata XML
   - Added tests for filtered results, valid score saving, clearing a score, scores below 0/above 100, malformed update lists, invalid status filters, and both read/write denial for a user without the HR permission.
   - Test setup creates a dedicated HR user with the permission set and a separate user without it, so access is exercised through `System.runAs` rather than relying on the current admin profile.
3. `force-app/main/default/lwc/hrTrainingResults/hrTrainingResults.js`, `.html` and `.js-meta.xml`
   - Added the HR Lightning component, with employee/training record pickers, a status filter, a read-only results table and inline score editing.
   - Added success/error feedback, loading and empty states, clearing of blank scores and a note explaining the 200-row cap.
4. `force-app/main/default/customPermissions/Manage_Training_Scores.customPermission-meta.xml`
   - Added the custom permission used by Apex as the server-side HR access gate.
5. `force-app/main/default/permissionsets/HR_Training_Manager.permissionset-meta.xml`
   - Added the HR permission set, including controller access and read-only access to all employee training assignments and their related Employee and Training records. It grants no create, delete or direct edit permission on those objects; score changes go through the guarded Apex method.
   - The permission set was deployed but was not assigned to any real user. HR user assignment and adding the component to an HR Lightning page remain setup actions for the org administrator.
6. `docs/DEVELOPMENT_LOG.md`
   - Recorded this implementation, encountered deployment/test issues, final deployment/test results and learning notes.

### Issues and fixes during deployment

1. The first deployment rejected `<isProtected>` in the CustomPermission metadata. Replaced it with the supported `<isLicensed>` element; the first attempt deployed no components and ran no tests.
2. The next deployment rejected `<apexClassAccesses>` in the permission set. Changed it to the metadata element `<classAccesses>`.
3. Salesforce then rejected explicit field-level permissions for required lookup fields (first the training category, then `Employee_Training__c.Employee__c`). Removed field-level entries and kept the permission set read-only at the object level. Apex is the only path in this feature that edits scores.
4. The first test version checked the current test user's assignment, and Salesforce reported the custom permission was not active in that context. Changed the fixture to create a dedicated permissioned HR user and run authorized controller calls as that user. This also gives the tests a realistic separation between HR and non-HR accounts.
5. That dedicated user initially had alias `hrtestuser`, which exceeded Salesforce's eight-character Alias limit. Changed it to `hrtest` and updated the test lookup.

### Deployment and verification

- Deployed only the new HR controller/test, custom permission, permission set and `hrTrainingResults` component to the connected VS Code org alias `mydevorg`.
- Final deployment completed all 5 requested metadata components and the specified Apex run reported **21 tests passed, 0 failed** across `HRTrainingControllerTest`, `TrainingAssignmentControllerTest` and `MyTrainingControllerTest`.
- The HR controller passed Salesforce's deployment-time Apex coverage requirement. The previously deployed `TrainingAssignmentController` and `MyTrainingController` remained included in the regression test run.
- The Apex/LWC metadata is deployed. At the time of the original deployment, the HR page had not yet been added or activated and the permission set had not been assigned. The user later reported adding the HR component/page in Salesforce. Assignment of the HR permission set to real HR users has not been confirmed.
- No employee or training business records were changed by the deployment. Test records were isolated within Apex tests.
- Local Jest tests were not run; this project has no installed `node_modules` directory. Salesforce successfully compiled and deployed the LWC bundle.
- The separate TDS UK apprenticeship project was not opened or modified.

### Learning notes

- A Lightning page can hide a control, but it cannot enforce access by itself. The Apex controller checks a Salesforce custom permission on both read and write calls, so a user cannot bypass the page and call the method directly.
- A permission set is additive. This HR permission set gives read access to all assignment, Employee and Training records so HR can filter across the workforce, while leaving standard create/edit/delete off. Only the guarded Apex score method changes an assignment.
- Apex validation is important even when a number input has a 0–100 range in the browser. Requests can come from another component or API, so the controller independently checks every submitted score.
- Bulk DML updates a group of scores with one database operation. Row locking serializes simultaneous updates to the same assignment so two transactions do not write it at once.
- Salesforce metadata uses specific XML element names and rejects field-level permission entries for required fields in this org. The final deployed permission set therefore uses object-level read access and a controller-level rule for the narrowly scoped score write.

## 2026-11-23 — Export filtered HR results to CSV

### Requested behavior

- The user approved a CSV export feature after confirming that a training progress chart already exists on the Home page.
- Added an **Export CSV** action to HR Training Results. The file contains the currently loaded filtered rows and the same maximum of 200 assignments as the table.
- Export fields: Employee, Employee Code, Training, Category, Assigned Date, Status, Completion Date and Score.
- The export button is disabled while score edits are unsaved, so the download cannot be mistaken for a file containing the pending edits.

### File changes

1. `force-app/main/default/lwc/hrTrainingResults/hrTrainingResults.js`
   - Added CSV headers and cell formatting that escapes quotes and wraps values correctly.
   - Added a UTF-8 CSV download named `hr-training-results-YYYY-MM-DD.csv`, using the browser's local date.
   - Added formula-injection protection by prefixing spreadsheet-formula-like text cells with an apostrophe. The browser only creates a local download; the CSV is not sent to an external service.
2. `force-app/main/default/lwc/hrTrainingResults/hrTrainingResults.html`
   - Added the Export CSV button above the results table and a reminder to save or cancel edits first.
3. `docs/DEVELOPMENT_LOG.md`
   - Recorded the feature and corrected the earlier page setup note to reflect the user's later confirmation that the component/page was added.

### Deployment and verification

- Deployed the updated `hrTrainingResults` Lightning component bundle to `mydevorg` through VS Code. Salesforce reported **Succeeded**, **1/1 component deployed**, and the bundle state was **Changed**.
- Salesforce completed its component compilation/deployment. No Apex tests were run in this phase because only the client-side Lightning component changed; the prior HR deployment's 21 passing Apex tests remain the latest Apex test result.
- The CSV button/download was not manually clicked in the org during this turn. After refreshing the HR page, an authorized HR user should confirm the file downloads and that its rows match the active filters.
- No Apex code or permission metadata changed in this feature. The export uses rows already returned by the HR-guarded Apex controller, so the HR custom permission remains required for the data shown and exported.
- The page component is reported by the user as added in Salesforce. Whether the HR permission set has been assigned to the user's HR account is not yet confirmed; the user should assign it only to authorized HR staff before using the page/export.

### Learning note

- CSV quoting keeps commas and quotes inside a cell from shifting columns. Prefixing values that begin with spreadsheet formula characters helps keep exported text as text when opened in spreadsheet software.

## 2026-11-23 — Training due dates and employee reminders

### Request and org field review

- The user requested a due-date reminder feature after agreeing to create the field.
- Inspected the connected Salesforce **Employee Training** object's Fields & Relationships list. Confirmed the user-created field is **Due Date**, API name `Due_Date__c`, type **Date**.
- The local project did not include the custom object metadata; those objects and fields are managed in the connected Salesforce org. No change was made to the separate TDS UK apprenticeship project.

### File changes

1. `force-app/main/default/classes/HRTrainingController.cls`
   - Included `Due_Date__c` in HR assignment retrieval.
   - Added `ResultUpdate` and a permission-guarded bulk update path to save due dates and/or scores together. This means editing both columns on one row is sent as a single server-side update, instead of two independent saves. Existing score updates delegate to the new path for backwards compatibility.
2. `force-app/main/default/classes/MyTrainingController.cls`
   - Included the assignment due date in the employee's own training query; employees still cannot edit that HR-managed date.
3. `force-app/main/default/lwc/hrTrainingResults/hrTrainingResults.js`
   - Added an editable Due Date table column and mapped the field into the existing bulk-save flow.
4. `force-app/main/default/lwc/myTraining/myTraining.js` and `.html`
   - Added a formatted due date and a status message: no due date, on track, due within seven days, due today, overdue by a number of days, or completed.
   - Due date messaging is informational; completed training is not marked overdue.
5. `docs/DEVELOPMENT_LOG.md`
   - Recorded the request, confirmed field/API name, code changes and learning concepts.

### Verification and deployment

- Deployed the two Apex controllers and two Lightning Web Component bundles to the connected `mydevorg` org using Salesforce CLI from the VS Code integrated terminal. Salesforce reported **Status: Succeeded**, **4 components**, **15 metadata files**, and no deployment warnings.
- Salesforce did not run tests in this deployment (`numberTestsCompleted: 0`, `numberTestErrors: 0`). Local Jest tests were also not run. This is a deployment result, not a test pass; the due-date feature still needs a hands-on check in the HR and employee pages.
- Apex tests were not added in this implementation step. The existing HR controller tests continue to exercise the score-save compatibility method. Due-date specific server validation is not in scope because HR can set or clear a date and no restriction on date range was requested.
- No employee training records were edited as part of the code change.

### Learning notes

- A due date belongs on `Employee_Training__c` because it describes the deadline for one employee's assignment, rather than a universal date on the reusable Training course.
- Apex reads the date and the HR-only save method updates it. The employee page displays the date and calculates reminder text in the browser from the local calendar date; it never lets an employee change the deadline.
- A custom permission check inside Apex protects the data update even if someone bypasses the HR Lightning component.

## 2026-11-23 — Due-date filtering in HR and My Trainings

### Requested behavior

- The user asked to add due-date filters to the HR Status dropdown and to the employee-facing My Trainings page.
- Due-date categories are `Overdue`, `Due Soon` (today through seven days from today), `On Track` (more than seven days away), and `No Due Date`. Completed assignments are excluded from overdue/due-soon/on-track categories. The existing Assigned, In Progress and Completed filters remain available.

### File changes

1. `force-app/main/default/classes/HRTrainingController.cls`
   - Extended the HR status filter validation to accept only the four supported due-date categories in addition to the existing training statuses.
   - Added date-aware query conditions so filtering happens in Salesforce before the 200-row limit is applied. This keeps HR results accurate when there are more than 200 assignments.
2. `force-app/main/default/lwc/hrTrainingResults/hrTrainingResults.js`
   - Added the due-date categories to the existing HR Status dropdown. The employee, training and status/deadline criteria continue to combine.
3. `force-app/main/default/lwc/myTraining/myTraining.js` and `.html`
   - Added a filter on the employee page for the same training and due-date categories. Filtering is applied before assignments are grouped into Completed, Assigned and In Progress sections.
   - Reused the due-date category calculation that already powers each assignment's reminder text, so a card's label and the filter use the same seven-day boundary.
4. `docs/DEVELOPMENT_LOG.md`
   - Recorded the requirements, files changed, behavior boundaries and learning concepts.

### Verification and deployment

- Deployed only `HRTrainingController` and the `hrTrainingResults` and `myTraining` Lightning component bundles to `mydevorg`. Salesforce reported **Succeeded**, **3 components deployed**, **13 metadata files**, **0 component errors**, and no warnings.
- No Apex or Jest tests were run (`numberTestsCompleted: 0`). Salesforce deployment compiled the changed Apex and LWC metadata; it did not execute behavior tests. A hands-on check of each dropdown in the org is still needed.
- No training assignment records were changed; the filter only changes which records are displayed.

### Learning notes

- Filtering rows in the HR Apex query means the limit applies to matching records, rather than loading the first 200 records and trying to filter an incomplete set in the browser.
- The employee page already loads only the current employee's assignments, so its dropdown filters that smaller list in the browser and preserves the existing status-group layout.
- Completed training is not counted as overdue, even when its stored due date is in the past.

## 2026-11-23 — Set due date while assigning training

### Requested behavior

- The user approved adding the due date to the HR training assignment form so the deadline is captured when the assignment is created.
- A due date is required for assignments created from the form and cannot be earlier than the assigned date. The assignment date remains prefilled with today and is now required in the form. The existing three-argument Apex method remains available for compatibility with existing callers and tests; the form uses the new four-argument `assignTrainingWithDueDate` method.

### File changes

1. `force-app/main/default/classes/TrainingAssignmentController.cls`
   - Added the due-date-aware assignment method and shared the record validation/creation logic between the new method and the existing method.
   - Saved `Due_Date__c` on the assignment. The server checks that the date is provided and is on or after the assigned date, even if a caller bypasses the form.
2. `force-app/main/default/lwc/trainingAssignmentForm/trainingAssignmentForm.js` and `.html`
   - Added a required Due Date date picker, constrained it to the assigned date or later, and passed its value to Apex.
   - After a successful assignment, the form clears the selections and resets the due-date entry.
3. `force-app/main/default/classes/TrainingAssignmentControllerTest.cls`
   - Added Apex tests that confirm the due date is saved, reject a missing date and reject a due date earlier than the assigned date.
4. `docs/DEVELOPMENT_LOG.md`
   - Recorded the requested feature, implementation, validation rules and learning concepts.

### Verification and deployment

- Deployed `TrainingAssignmentController`, `TrainingAssignmentControllerTest` and the `trainingAssignmentForm` Lightning component bundle to `mydevorg`. Salesforce reported **Succeeded**, **3 components deployed**, **11 metadata files**, **0 component errors**, and no warnings.
- Ran `TrainingAssignmentControllerTest` against `mydevorg` with code coverage. Result: **Passed — 10 tests run, 10 passed, 0 failed, 0 skipped**. `TrainingAssignmentController` coverage is **100%**. The org-wide Apex coverage reported **9%**; this is a separate org-wide figure and does not change the controller's 100% class coverage result.
- The new tests verify that Due Date is saved and that a missing date or a date earlier than the assigned date is rejected. Existing assignment validations also passed.
- No training assignment business records were changed by deployment or tests; all test records were created by the isolated Apex test setup.

### Learning notes

- A required field in the form helps the user, but it is not enough to protect data because code can call Apex without using that form. The controller repeats the due-date checks on the server.
- The old Apex method stays in place for compatibility. The new form calls a due-date-specific method so the new required deadline behavior is explicit and existing callers do not break.
- The Due Date is stored on each `Employee_Training__c` assignment, because the deadline can differ for each employee even when the training program is the same.
- Apex test coverage reports which controller lines ran; the test assertions verify that the expected date was actually saved and invalid dates were rejected.

## 2026-11-23 — Bulk training assignment by department

### Requested behavior

- The user approved an HR option to assign one active training program to every active employee in a selected department, with one assigned date and due date for the batch.
- Keep the existing single-employee assignment option. Department assignment must skip employees who already have the selected training and show counts for assigned, skipped and failed rows.

### File changes

1. `force-app/main/default/classes/TrainingAssignmentController.cls`
   - Added the `assignTrainingToDepartment` Apex method and a small summary response containing assigned, duplicate and failed counts plus the first row error, when present.
   - The method confirms that the training is active, selects only active employees in the chosen department, locks those employee records, skips existing employee/training pairs, then inserts the remaining assignments in one bulk operation with partial-success results.
   - Applied the same required due-date and assigned-date rules. A guard rejects more than 10,000 active employees in a department so a request cannot exceed Salesforce's per-transaction DML row limit.
2. `force-app/main/default/lwc/trainingAssignmentForm/trainingAssignmentForm.js` and `.html`
   - Added an **Assign To** choice for one employee or an entire department.
   - Department mode shows a department picker and labels the due date as applying to each employee. It uses the existing due-date and training selection, then shows a toast summary when Salesforce finishes.
   - Individual mode remains available and uses the existing due-date-aware assignment method.
3. `force-app/main/default/classes/TrainingAssignmentControllerTest.cls`
   - Added an Apex test for department assignment: it confirms one assignment is created with the due date, a repeat request skips that employee as a duplicate, and the counts match.
4. `docs/DEVELOPMENT_LOG.md`
   - Recorded the request, server-side protections, response behavior and learning concepts.

### Verification and deployment

- Deployed `TrainingAssignmentController`, `TrainingAssignmentControllerTest` and the `trainingAssignmentForm` Lightning component bundle to `mydevorg`. Salesforce reported **Succeeded**, **3 components deployed**, **11 metadata files**, **0 component errors**, and no warnings. Deployment was performed with `NoTestRun`; the Apex test class was then run separately.
- Ran `TrainingAssignmentControllerTest` against `mydevorg` with code coverage. Result: **Passed — 11 tests run, 11 passed, 0 failed, 0 skipped**. `TrainingAssignmentController` coverage is **82%**. The org-wide Apex coverage reported **16%**, which is a separate org-wide figure.
- The added department-assignment test confirms the first call creates the assignment with its due date and a repeat call skips the already-assigned employee. Existing controller validation tests also passed.
- The Apex tests use isolated test setup records. No real Employee Training records were bulk assigned during implementation or deployment.

### Learning notes

- Bulk DML lets Apex insert many assignment records in one database operation instead of making a separate insert for every employee.
- The controller checks duplicates before inserting and locks employees during that check so simultaneous requests through this controller cannot both pass for the same employee.
- `Database.insert(records, false)` allows valid rows to succeed even if a particular assignment fails validation; the response counts those outcomes for HR.
- A limit check protects the transaction from trying to insert more records than Salesforce allows in one transaction.

## 2026-11-23 — Project team workspace

### Requested behavior

- The user redirected the next project phase from training reminders to project assignment and work on the Projects page.
- Add a team workspace on Project records so an administrator can assign an active Employee to the current Project and review the assigned team with allocation start/end dates.
- Preserve existing Project Status fields and existing project records. Do not modify the separate TDS UK apprenticeship project or its related records.

### Existing Salesforce setup inspected

- `Project__c` already stores project details and an overall Project Status.
- `Project_Allocation__c` is the existing employee-to-project junction object. Its fields include `Employee__c`, `Project__c`, `Allocation_Start_Date__c`, and `Allocation_End_Date__c`.
- The Project Allocations list was empty during inspection. The Salesforce form already supports manual assignment, but does not show a team workspace on the Project record.
- The Salesforce Projects list also contains a record named `TDS UK Implementation`; it was not edited or selected.

### File changes

1. `force-app/main/default/classes/ProjectWorkspaceController.cls` and `.cls-meta.xml`
   - Added a controller to read up to 200 assignment rows for the current project and create new Project Allocation records.
   - Server-side checks require both lookups, restrict assignment to active employees, reject an end date before a start date, and prevent overlapping allocations of the same employee to the same project.
   - Uses user-mode Salesforce access for queries and inserts so the operation respects the current user's access.
2. `force-app/main/default/lwc/projectTeamWorkspace/projectTeamWorkspace.js`, `.html`, and `.js-meta.xml`
   - Added a record-page component that filters the employee picker to active employees, accepts optional allocation dates, and displays the current assigned team.
   - The component refreshes its roster after a successful assignment and shows a user-readable error if validation fails.
   - Restricted the component's record-page target to Project records.
3. `docs/DEVELOPMENT_LOG.md`
   - Recorded the feature scope, inspected Salesforce schema, safety boundary, code changes, and learning concepts.

### Verification and deployment

- Deployed `ProjectWorkspaceController` and the `projectTeamWorkspace` Lightning component bundle to `mydevorg`. Salesforce reported **Succeeded**, **2 components deployed**, **9 metadata files**, **0 component errors**, and no warnings. Deployment used `NoTestRun`; no Apex tests were run for this feature in this phase.
- Created and saved the `Project Team Workspace` Lightning **Record Page** for the custom Project object (`Project__c`). The component renders in the page preview. The page is saved, but app-default activation is not yet confirmed; Salesforce showed a page-property warning during activation setup, so assignment to the Employee Management System app remains pending.
- No Project Allocation or Project business records were created or modified while building or deploying the component. The TDS UK project was not opened or changed.

### Learning notes

- `Project_Allocation__c` is a junction object: each row connects one employee to one project and can hold dates for that relationship.
- The workspace uses the existing relationship rather than putting a list of employee names into a single Project text field. That keeps assignments searchable and reportable.
- Date checks run both in the form and Apex. The form gives quick feedback; Apex enforces the rule even if another caller bypasses the form.
- Apex returns a small row wrapper to the table so the UI gets readable employee names and dates without exposing unrelated record fields.
- A Lightning Record Page is a different page type from an App Page: the Record Page receives the current Project record ID, which lets the component load and create allocations for that specific project.
- Saving a record page and making it visible to users are separate steps. Activation assigns the page to an app, object, or profile; this page still needs a clean app-specific activation before it appears as the default page in Employee Management System.

## 2026-11-24 — Assign projects from an employee record

### Requested behavior

- Add an employee-side component so a user can open an Employee record, choose a Project, enter optional allocation dates, assign it, and review that employee's existing project allocations.
- Keep the existing Project-side team workspace. Both directions use the same `Project_Allocation__c` relationship object and the same server-side assignment rules.
- Do not change project or allocation business records during implementation. Do not access or modify the separate TDS UK apprenticeship project.

### Project review

- Re-read the Salesforce DX package configuration, project tree, controller classes, related Lightning components, Apex tests, and the existing development log before editing.
- Confirmed `ProjectWorkspaceController.assignEmployeeToProject` already performs the insert and enforces active-employee, date-order, and overlapping-allocation rules. The new component reuses this method to keep the rules consistent.
- Confirmed the portfolio already queries the Project code, status, and client fields needed for the employee's assignment list. The repository contains no local custom-object metadata; these schema definitions live in the connected org.
- The repository does not contain a Git working tree, so this change cannot be summarized using `git diff` or `git status`.

### File changes

1. `force-app/main/default/classes/ProjectWorkspaceController.cls`
   - Added `getEmployeeProjects(employeeId)`, which returns up to 200 allocation rows for one employee, including the related project's name, code, status, client, and allocation dates.
   - The query uses `WITH USER_MODE` so the current user's Salesforce object and field permissions are respected.
2. `force-app/main/default/lwc/employeeProjectWorkspace/employeeProjectWorkspace.js`
   - Added the employee-page behavior: load the employee's projects, select a Project record, submit allocation dates through the existing Apex method, refresh the list, and show success or validation messages.
3. `force-app/main/default/lwc/employeeProjectWorkspace/employeeProjectWorkspace.html`
   - Added the Project picker, allocation date fields, Assign project button, loading indicator, and assigned-project table with links to the Project records.
4. `force-app/main/default/lwc/employeeProjectWorkspace/employeeProjectWorkspace.js-meta.xml`
   - Exposed the component in Lightning App Builder only for `Employee__c` record pages.
5. `force-app/main/default/objects/Project_Allocation__c/Project_Allocation__c.object-meta.xml` and `fields/Project__c.field-meta.xml`
   - Retrieved the existing allocation object's relationship metadata from the org. The field metadata currently points to `DevopsProject`; the local `referenceTo` was changed to `Project__c` after the user selected Employee Management projects as the intended target.
6. `docs/DEVELOPMENT_LOG.md`
   - Recorded the request, reviewed dependencies, file-level changes, safety boundaries, and learning notes.

### Verification and deployment

- First deployment attempt to the connected Developer Edition org failed at Apex compilation: `Project_Allocation__c.Project__c` points to Salesforce's `DevopsProject` object, which has no `Project_Code__c` field. The LWC bundle also failed because the referenced Apex method did not compile. Salesforce reported 2 component errors and 0 tests run; no Apex or LWC behavior tests were run.
- Follow-up read-only schema inspection confirmed `Project__c` is the Employee Management app's custom Project object and it contains Project Code, Project Status, Client Name, Start Date and End Date. However, the Project lookup on `Project_Allocation__c` points to the separate `DevopsProject` object, whose fields are Name, Description, Is Active and External Id. The junction object currently has 0 rows.
- The user selected Employee Management `Project__c` records as the intended target. A second deployment attempt failed because Salesforce rejected an in-place lookup target change with `Cannot update referenceTo`; the Apex class consequently still cannot compile against the old relationship type. The LWC bundle also failed because its Apex method did not compile. The deployment had 3 component errors and 0 tests run; no Apex or LWC behavior tests were run.
- Deployment and in-org page placement remain pending. Salesforce requires replacing the existing relationship field (rather than changing `referenceTo` in place) or using a different allocation data model. No business records were created or updated. The separate TDS UK apprenticeship project was not accessed or changed.
- No Apex or Jest tests have been run for this employee-side component in this phase. No business records have been created or updated.

### Learning notes

- The Employee and Project records connect through `Project_Allocation__c`, which stores one assignment and its dates per row. The Employee component shows the employee's rows; the Project component shows the project's rows.
- Reusing the existing Apex method means both screens enforce the same active-employee, date, and overlap rules. The screen helps users, while Apex remains the final safeguard.
- `@api recordId` gives a Lightning record-page component the ID of the current Employee. The Apex query uses that ID to load only that employee's allocations.
- A Lightning component can be exposed for a specific object in its metadata file. This makes the new component available in App Builder for Employee pages without making it available on unrelated record types.
- Salesforce object labels can be misleadingly similar: the custom `Project__c` and standard `DevopsProject` are different objects. A lookup's `referenceTo` target determines which record IDs it can store. The user's project screens use `Project__c`, while the current allocation lookup targets `DevopsProject`; the relationship target must be settled before assignment can work against the intended project records.
- Salesforce rejected an in-place `referenceTo` edit for the existing master-detail field. Changing a relationship's target can require deleting and recreating the metadata field, which has dependency implications even when the allocation table has no rows.

### Deployment status update — 2026-11-24

The earlier verification section above was written before the relationship replacement and final deployment were completed. This update records the final outcome and supersedes its statements that deployment was still pending.

- The user confirmed the target should be the Employee Management System's custom `Project__c` object and authorized replacing `Project_Allocation__c.Project__c` because Salesforce does not permit changing the target of an existing master-detail field in place.
- Salesforce required two separate deployment steps. First, a temporary maintenance version of `ProjectWorkspaceController` was deployed so the Apex dependency on the field could be removed. The field was then deleted in a successful deployment. Second, the same field name was recreated as a master-detail relationship to custom `Project__c`, and the final controller and `employeeProjectWorkspace` Lightning Web Component were deployed successfully.
- Final deployment result: **Succeeded**, 3 components deployed (Apex class, custom field, LWC bundle), 0 errors, 0 warnings, and 0 tests run. No Apex or Jest tests were run for this feature. The final controller source in the DX project is the full implementation, not the temporary maintenance stub.
- There were no `Project_Allocation__c` rows before the field replacement. No Employee, Project, or Project Allocation business records were created or changed during this work.
- No Employee Lightning Record Page was created or activated. The user will place the deployed component on the desired Employee record page and deploy/manage that page from their own VS Code/Salesforce workflow. Further Salesforce UI changes are outside the current scope.
- Learning concept: Salesforce metadata deployment can require multiple steps when a field has dependencies. A temporary compatibility version can remove the code dependency, then a later deployment can recreate the relationship and restore the final implementation. The Salesforce org and local DX source must be kept in sync after such a sequence.
- Working preference: continue coding and logging in the `Employee-Management-System` VS Code project; do not use the Salesforce UI for page placement. The separate TDS UK apprenticeship project remains untouched.

## 2026-11-24 — Deploy and test Employee Project Assignments

### Files changed in this phase

1. `force-app/main/default/classes/ProjectWorkspaceControllerTest.cls` — added five Apex behavior tests with isolated `@TestSetup` Department, Employee, and Project records. The tests cover: successful allocation plus both employee/project list queries; null inputs and wrong record types; date-order validation; inactive employee rejection; duplicate/overlapping allocation rejection; allowing a later non-overlapping allocation; and optional blank allocation dates.
2. `force-app/main/default/classes/ProjectWorkspaceControllerTest.cls-meta.xml` — added the Apex class metadata file at API version 68.0.
3. `docs/DEVELOPMENT_LOG.md` — recorded this deployment, test outcomes, coverage, and UI-test limitation.

The controller and LWC source were reviewed but not changed in this phase. Their deployment status was verified against the org. The Project lookup in the org points to `Project__c`.

### Deployment and test results

- Target org: Employee Management System Developer Edition (`EmployeeManagementOrg` alias).
- Deployed `ProjectWorkspaceController`, `ProjectWorkspaceControllerTest`, and the `employeeProjectWorkspace` LWC bundle with the test level set to `RunSpecifiedTests` for `ProjectWorkspaceControllerTest`.
- Deployment result: **Succeeded**. Salesforce reported the controller unchanged, the new Apex test created, and the Lightning component bundle changed. Deployment test summary: **5 passing, 0 failing**.
- A follow-up detailed Apex run passed all five behavior test methods; Salesforce counted 6 executions including the shared `@TestSetup` method. `ProjectWorkspaceController` coverage: **100%**. Org-wide coverage was 25%, a separate org-level statistic.
- The tests create only isolated test records. No real Employee, Project, or Project Allocation records were created or modified.
- No LWC Jest test is present for `employeeProjectWorkspace`, and the local Jest runner is not installed (`node_modules/.bin/sfdx-lwc-jest` is absent). The Salesforce deployment successfully compiled the LWC bundle, and Apex tests verified its server-side controller, but no browser interaction or rendered-page test was run. The Employee record page has not been modified; the user will place and activate the component on the desired page.

### Learning concepts

- An Apex unit test creates temporary records so the controller can be checked without depending on the org's business data. `@TestSetup` creates a shared baseline for each test method.
- Coverage measures which Apex lines executed; assertions check expected behavior. The controller reached 100% coverage and every test assertion passed.
- Deploying an LWC bundle proves Salesforce can compile and install its source. A Jest or browser test is needed to validate client-side interactions; those were not run in this phase.
- `RunSpecifiedTests` makes the deployment run the focused test class instead of the entire org test suite.

## 2026-11-24 — Standalone Project Allocation Workspace

### Requested behavior

- The user clarified that the assignment workspace should live in the Project Allocations area, rather than on an individual Employee record.
- Added a standalone Lightning App Page component so a user can select an active Employee and a Project, enter optional allocation dates, create the assignment, and review recent allocations.
- Kept `employeeProjectWorkspace` available for Employee record pages; it remains a separate experience.

### Files changed

1. `force-app/main/default/classes/ProjectWorkspaceController.cls`
   - Added cacheable `getProjectAllocations()` to return up to 200 recent allocation records, including employee name, project name/code/status/client, and allocation dates.
   - The query uses `WITH USER_MODE` so it respects the current user's object and field access.
2. `force-app/main/default/classes/ProjectWorkspaceControllerTest.cls`
   - Extended the successful assignment test to check the new all-allocations query and its employee/project relationship details.
3. `force-app/main/default/lwc/projectAllocationWorkspace/projectAllocationWorkspace.js`
   - Added the page behavior: active-employee picker, project picker, date validation, call to the existing assignment method, refresh, and readable success/error messages.
4. `force-app/main/default/lwc/projectAllocationWorkspace/projectAllocationWorkspace.html`
   - Added the two selectors, date fields, Assign project button, loading indicator, and recent-allocation table.
5. `force-app/main/default/lwc/projectAllocationWorkspace/projectAllocationWorkspace.js-meta.xml`
   - Exposed the new component for Lightning App Pages under the label **Project Allocation Workspace**.
6. `docs/DEVELOPMENT_LOG.md`
   - Recorded this implementation and its deployment/test status.

### Verification and deployment status

- Parsed the new component metadata XML successfully.
- The Salesforce CLI Jest runner is not installed locally, and no Jest test bundle exists for the new component. The JavaScript source uses LWC decorators, which the plain Node syntax checker does not understand; this result is not a Salesforce compile result.
- This latest workspace change has **not** been deployed or tested in the org. The controller test source now covers the new query, but must be deployed and run before its result can be treated as verified. The user asked to handle page placement/deployment in their own Salesforce workflow.
- No Salesforce page configuration or business data was changed. The separate TDS UK apprenticeship project remains untouched.

### Learning notes

- An App Page is a standalone workspace that can be added to an app's navigation. A Record Page is tied to one particular Employee, Project, or allocation record.
- A standalone allocation workspace cannot rely on `recordId` being an Employee ID, so it has its own Employee picker and uses the selected Employee ID when calling the existing Apex assignment method.
- The screen handles quick input feedback, while Apex still enforces required choices, active employee status, date order, and duplicate/overlap rules.

## 2026-11-24 — Local automated test setup

### Repository review and scope

- Inspected `package.json`, `sfdx-project.json`, `jest.config.js`, all seven LWC bundles, their Apex controller contracts, all four existing Apex test classes, and this development log.
- Kept `sources/` and the separate TDS UK apprenticeship project out of scope; no files in either project were opened or changed.
- The project already declares `@salesforce/sfdx-lwc-jest` and test scripts, and `jest.config.js` already imports the Salesforce Jest configuration. No Jest config changes were needed. There is no local `node_modules` directory, so the declared runner is unavailable in this checkout.
- Playwright is not declared or installed. The application is Salesforce-hosted, and the repository has no local app server, safe browser session fixture, or seeded E2E environment. No Playwright suite was added because it could not be run safely or locally without org setup and dependency installation.
- No Salesforce login, org-data change, deployment, dependency installation, or use of a real user/session was performed. The Apex tests were reviewed as source only; running them requires a safe Salesforce test org and was not attempted.

### Test changes

- Replaced the generated TODO in `trainingAssignmentForm/__tests__/trainingAssignmentForm.test.js` with checks for required form state, employee assignment arguments, and department assignment routing.
- Added Jest suites for `hrTrainingResults`, `myTraining`, `projectPortfolio`, `projectTeamWorkspace`, `employeeProjectWorkspace`, and `projectAllocationWorkspace`. They cover wire data mapping, filtering/loading states, Apex mutation arguments, and client-side date validation.
- Kept the existing Apex test classes unchanged. Their source covers successful assignment/list queries, missing and wrong IDs, inactive employee/training rejection, duplicate and overlap rules, status/date/score validation, HR permission checks, employee ownership, and missing/duplicate employee mappings.
- Added `ProjectPortfolioControllerTest.cls` and its metadata because the portfolio controller had no test class. The test creates two isolated projects and asserts returned portfolio fields and name ordering.

### Actual verification results and limitations

- `node -e` parsing of `package.json` and `sfdx-project.json`: **Passed**.
- `npm.cmd test -- --runInBand`: **Could not run tests**; the npm script started, but Windows reported `sfdx-lwc-jest` is not recognized because dependencies are not installed. No Jest test is reported as passed.
- An `npx eslint` attempt was blocked before execution by the PowerShell script execution policy. ESLint was not run.
- Apex tests: **Not run**; they require Salesforce execution, which was outside the approved actions. The new portfolio test is source-only until run in a safe test org. Historical org test results elsewhere in this log are not results from this task.
- Playwright E2E: **Not added or run** because there is no declared/installed Playwright runner or safe local/browser test environment.

### Local Jest run update — 2026-11-24

- After the user installed the already-declared dependencies, ran `npm.cmd test` locally.
- The first run exposed test harness setup issues (Jest mock-hoisting with Apex wire adapters and date event values); corrected the Jest mocks and fixtures, then reran the suite.
- Final result: **7 test suites passed, 16 tests passed, 0 failed, 0 skipped**. This is the local LWC Jest result only. Apex tests were not run against Salesforce, and no org login, deployment, or data change occurred.

### Salesforce validation and deployment update — 2026-11-24

- The user explicitly authorized deploying `force-app` to the connected Developer Edition org alias `dheer`. Salesforce CLI had a trailing space in the stored alias, so the CLI target was passed as `dheer `; it resolved to the connected Developer Edition org.
- The first dry-run validation processed all 22 metadata components and ran 57 Apex tests: **56 passed, 1 failed**. The new `ProjectPortfolioControllerTest` used `Active`, which is not an allowed value for the org's restricted Project Status picklist.
- Read the active Project Status values from the org schema and corrected the isolated test fixture to `In Progress`. The test data is created in Apex test context; no business records were inserted directly into the org.
- Reran local Jest after the fixture correction: **7 suites passed, 16 tests passed, 0 failed**.
- Full `force-app` dry-run validation then succeeded: **57 Apex tests passed, 0 failed**, with no deployment errors.
- Deployed `force-app` to the authorized Developer Edition org. Final result: **Succeeded**; 22 metadata components processed, with 57 Apex tests passing and 0 failing. Salesforce reported the new `ProjectPortfolioControllerTest` class and metadata as Created; the existing Apex classes were unchanged, and the seven existing LWC bundles and HR permission set were updated. No Playwright tests were run.

### Final deployment and test update — 2026-11-24

This update supersedes the earlier local-only deployment status in the Standalone Project Allocation Workspace section above.

- The first deployment attempt failed during its test run because the test's `getProject()` query selected the Project ID and code but not the Name field that a new assertion read. Salesforce rolled back that deployment. Fixed the test helper to query `Name`.
- Retried deployment of `ProjectWorkspaceController`, `ProjectWorkspaceControllerTest`, and `projectAllocationWorkspace`. Result: **Succeeded**; both Apex classes and the new Lightning component bundle were deployed; **5 passing, 0 failing** deployment test methods.
- Ran `ProjectWorkspaceControllerTest` again with code coverage. All five behavior methods passed; Salesforce counted six executions including `@TestSetup`. `ProjectWorkspaceController` coverage: **100%**.
- Salesforce deployment compiled the new LWC bundle. No Jest/browser interaction test was run because the Jest runner and a component Jest test file are not installed/present locally.
- The standalone component is now deployed under the label **Project Allocation Workspace** and is exposed to **Lightning App Pages**. No App Page was created or activated, and no existing navigation or record page was modified. The user will place the component on the page and add it to the app navigation.
- Test records were isolated to the Apex test context. No real Employee, Project, or Project Allocation records were created or changed. The TDS UK apprenticeship project was not accessed or modified.
