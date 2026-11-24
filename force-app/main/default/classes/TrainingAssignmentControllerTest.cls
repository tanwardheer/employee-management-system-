
@IsTest
private class TrainingAssignmentControllerTest {

    // Create independent sample data for our tests
    @TestSetup
    static void createTestData() {

        // Create Department
        departement__c dept = new departement__c(
            Name = 'Test Logistics',
            Department_Code__c = 'TEST-DEPT-01'
        );
        insert dept;

        // Create Employee
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            Employee_code__c = 'TEST-EMP-01',
            Email__c = 'testemployee@example.com',
            Phone__c = '555-010-1001',
            Date_of_joining__c = Date.today(),
            Designation__c = 'Developer',
            Employment_Status__c = 'Active',
            department__c = dept.Id
        );
        insert emp;

        // Create two Training records
        List<Training__c> trainings = new List<Training__c>();

        trainings.add(new Training__c(
            Name = 'Test Apex Training',
            Training_code__c = 'TEST-TRN-01',
            Training_Category__c = 'Technical',
            Duration_Hours__c = 10,
            Active__c = true
        ));

        trainings.add(new Training__c(
            Name = 'Test Admin Training',
            Training_code__c = 'TEST-TRN-02',
            Training_Category__c = 'Technical',
            Duration_Hours__c = 12,
            Active__c = true
        ));

        insert trainings;
    }

    // Test 1: Successful assignment
    @IsTest
    static void testSuccessfulAssignment() {

        Employee__c emp = [
            SELECT Id FROM Employee__c LIMIT 1
        ];

        Training__c training = [
            SELECT Id FROM Training__c
            WHERE Training_code__c = 'TEST-TRN-01'
            LIMIT 1
        ];

        Test.startTest();

        Id assignmentId = TrainingAssignmentController.assignTraining(
            emp.Id,
            training.Id,
            Date.today()
        );

        Test.stopTest();

        Employee_Training__c result = [
            SELECT Id, Employee__c, Training__c,
                   Training_Status__c, Assigned_Date__c
            FROM Employee_Training__c
            WHERE Id = :assignmentId
        ];

        System.assertEquals(emp.Id, result.Employee__c);
        System.assertEquals(training.Id, result.Training__c);
        System.assertEquals('Assigned', result.Training_Status__c);
        System.assertEquals(Date.today(), result.Assigned_Date__c);
    }

    @IsTest
    static void testAssignmentSavesDueDate() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Training__c training = [
            SELECT Id FROM Training__c
            WHERE Training_code__c = 'TEST-TRN-01'
            LIMIT 1
        ];
        Date dueDate = Date.today().addDays(14);

        Id assignmentId = TrainingAssignmentController.assignTrainingWithDueDate(
            emp.Id, training.Id, Date.today(), dueDate
        );

        Employee_Training__c result = [
            SELECT Assigned_Date__c, Due_Date__c
            FROM Employee_Training__c
            WHERE Id = :assignmentId
        ];
        System.assertEquals(Date.today(), result.Assigned_Date__c);
        System.assertEquals(dueDate, result.Due_Date__c);
    }

    @IsTest
    static void testDueDateIsRequiredAndCannotPrecedeAssignedDate() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Training__c training = [SELECT Id FROM Training__c LIMIT 1];

        Boolean missingDateRejected = false;
        try {
            TrainingAssignmentController.assignTrainingWithDueDate(
                emp.Id, training.Id, Date.today(), null
            );
        } catch (AuraHandledException ex) {
            missingDateRejected = true;
        }
        System.assertEquals(true, missingDateRejected);

        Boolean earlierDateRejected = false;
        try {
            TrainingAssignmentController.assignTrainingWithDueDate(
                emp.Id,
                training.Id,
                Date.today(),
                Date.today().addDays(-1)
            );
        } catch (AuraHandledException ex) {
            earlierDateRejected = true;
        }
        System.assertEquals(true, earlierDateRejected);
    }

    @IsTest
    static void testDepartmentAssignmentSetsDueDateAndSkipsDuplicates() {
        Employee__c emp = [
            SELECT department__c
            FROM Employee__c
            WHERE Employee_code__c = 'TEST-EMP-01'
            LIMIT 1
        ];
        Training__c training = [
            SELECT Id FROM Training__c
            WHERE Training_code__c = 'TEST-TRN-01'
            LIMIT 1
        ];
        Date dueDate = Date.today().addDays(21);

        Test.startTest();
        TrainingAssignmentController.AssignmentSummary firstResult =
            TrainingAssignmentController.assignTrainingToDepartment(
                emp.department__c, training.Id, Date.today(), dueDate
            );
        TrainingAssignmentController.AssignmentSummary secondResult =
            TrainingAssignmentController.assignTrainingToDepartment(
                emp.department__c, training.Id, Date.today(), dueDate
            );
        Test.stopTest();

        System.assertEquals(1, firstResult.assignedCount);
        System.assertEquals(0, firstResult.duplicateCount);
        System.assertEquals(0, firstResult.failedCount);
        System.assertEquals(0, secondResult.assignedCount);
        System.assertEquals(1, secondResult.duplicateCount);
        System.assertEquals(0, secondResult.failedCount);

        Employee_Training__c savedAssignment = [
            SELECT Due_Date__c, Training_Status__c
            FROM Employee_Training__c
            WHERE Employee__r.Employee_code__c = 'TEST-EMP-01'
            AND Training__c = :training.Id
            LIMIT 1
        ];
        System.assertEquals(dueDate, savedAssignment.Due_Date__c);
        System.assertEquals('Assigned', savedAssignment.Training_Status__c);
    }

    // Test 2: Duplicate assignment prevention
    @IsTest
    static void testDuplicateAssignment() {

        Employee__c emp = [
            SELECT Id FROM Employee__c LIMIT 1
        ];

        Training__c training = [
            SELECT Id FROM Training__c
            WHERE Training_code__c = 'TEST-TRN-01'
            LIMIT 1
        ];

        // First assignment should succeed
        TrainingAssignmentController.assignTraining(
            emp.Id, training.Id, Date.today()
        );

        Boolean duplicateErrorThrown = false;

        Test.startTest();

        // Second assignment should fail
        try {
            TrainingAssignmentController.assignTraining(
                emp.Id, training.Id, Date.today()
            );
        } catch (AuraHandledException ex) {
            duplicateErrorThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            duplicateErrorThrown,
            'Duplicate assignment should be rejected.'
        );

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Employee_Training__c
             WHERE Employee__c = :emp.Id AND Training__c = :training.Id],
            'Only one assignment should exist for an employee and training.'
        );
    }

    // Test 3: Different training should be allowed
    @IsTest
    static void testDifferentTrainingAssignment() {

        Employee__c emp = [
            SELECT Id FROM Employee__c LIMIT 1
        ];

        List<Training__c> trainings = [
            SELECT Id FROM Training__c
            ORDER BY Training_code__c
        ];

        Test.startTest();

        Id firstAssignment =
            TrainingAssignmentController.assignTraining(
                emp.Id, trainings[0].Id, Date.today()
            );

        Id secondAssignment =
            TrainingAssignmentController.assignTraining(
                emp.Id, trainings[1].Id, Date.today()
            );

        Test.stopTest();

        System.assertNotEquals(firstAssignment, secondAssignment);
    }

    // Test 4: Missing employee or training ID
    @IsTest
    static void testMissingInput() {

        Training__c training = [
            SELECT Id FROM Training__c LIMIT 1
        ];

        Boolean employeeError = false;
        Boolean trainingError = false;

        try {
            TrainingAssignmentController.assignTraining(
                null, training.Id, Date.today()
            );
        } catch (AuraHandledException ex) {
            employeeError = true;
        }

        try {
            TrainingAssignmentController.assignTraining(
                UserInfo.getUserId(), null, Date.today()
            );
        } catch (AuraHandledException ex) {
            trainingError = true;
        }

        System.assertEquals(true, employeeError);
        System.assertEquals(true, trainingError);

        Boolean wrongEmployeeTypeError = false;
        Boolean wrongTrainingTypeError = false;

        try {
            TrainingAssignmentController.assignTraining(
                UserInfo.getUserId(), training.Id, Date.today()
            );
        } catch (AuraHandledException ex) {
            wrongEmployeeTypeError = true;
        }

        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        try {
            TrainingAssignmentController.assignTraining(
                emp.Id, UserInfo.getUserId(), Date.today()
            );
        } catch (AuraHandledException ex) {
            wrongTrainingTypeError = true;
        }

        System.assertEquals(true, wrongEmployeeTypeError);
        System.assertEquals(true, wrongTrainingTypeError);
    }

    // Test 5: Inactive employees cannot receive training
    @IsTest
    static void testInactiveEmployeeRejected() {
        Employee__c emp = [SELECT Id, Employment_Status__c FROM Employee__c LIMIT 1];
        Training__c training = [SELECT Id FROM Training__c LIMIT 1];
        emp.Employment_Status__c = 'Inactive';
        update emp;

        Boolean errorThrown = false;
        try {
            TrainingAssignmentController.assignTraining(
                emp.Id, training.Id, Date.today()
            );
        } catch (AuraHandledException ex) {
            errorThrown = true;
        }

        System.assertEquals(true, errorThrown, 'Inactive employees must be rejected.');
        System.assertEquals(0, [SELECT COUNT() FROM Employee_Training__c]);
    }

    // Test 6: Inactive training programs cannot be assigned
    @IsTest
    static void testInactiveTrainingRejected() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Training__c training = [SELECT Id, Active__c FROM Training__c LIMIT 1];
        training.Active__c = false;
        update training;

        Boolean errorThrown = false;
        try {
            TrainingAssignmentController.assignTraining(
                emp.Id, training.Id, Date.today()
            );
        } catch (AuraHandledException ex) {
            errorThrown = true;
        }

        System.assertEquals(true, errorThrown, 'Inactive trainings must be rejected.');
        System.assertEquals(0, [SELECT COUNT() FROM Employee_Training__c]);
    }

    // Test 7: A blank assigned date defaults to today
    @IsTest
    static void testNullAssignedDateDefaultsToToday() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Training__c training = [SELECT Id FROM Training__c LIMIT 1];

        Id assignmentId = TrainingAssignmentController.assignTraining(
            emp.Id, training.Id, null
        );

        Employee_Training__c assignment = [
            SELECT Assigned_Date__c
            FROM Employee_Training__c
            WHERE Id = :assignmentId
        ];
        System.assertEquals(Date.today(), assignment.Assigned_Date__c);
    }
}
