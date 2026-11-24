@IsTest
private class MyTrainingControllerTest {
    @TestSetup
    static void createTestData() {
        departement__c department = new departement__c(
            Name = 'My Training Test Department',
            Department_Code__c = 'MY-TRAIN-DEPT'
        );
        insert department;

        Employee__c linkedEmployee = new Employee__c(
            Name = 'Linked Test Employee',
            Employee_code__c = 'MY-TRAIN-EMP-01',
            Email__c = 'linked.employee@example.com',
            Phone__c = '555-010-2001',
            Date_of_joining__c = Date.today(),
            Designation__c = 'Developer',
            Employment_Status__c = 'Active',
            department__c = department.Id,
            Salesforce_user__c = UserInfo.getUserId()
        );
        Employee__c unlinkedEmployee = new Employee__c(
            Name = 'Other Test Employee',
            Employee_code__c = 'MY-TRAIN-EMP-02',
            Email__c = 'other.employee@example.com',
            Phone__c = '555-010-2002',
            Date_of_joining__c = Date.today(),
            Designation__c = 'Analyst',
            Employment_Status__c = 'Active',
            department__c = department.Id
        );
        insert new List<Employee__c>{ linkedEmployee, unlinkedEmployee };

        Training__c training = new Training__c(
            Name = 'My Training Test Course',
            Training_code__c = 'MY-TRAIN-COURSE',
            Training_Category__c = 'Technical',
            Duration_Hours__c = 8,
            Active__c = true
        );
        insert training;

        insert new List<Employee_Training__c>{
            new Employee_Training__c(
                Employee__c = linkedEmployee.Id,
                Training__c = training.Id,
                Training_Status__c = 'Assigned',
                Assigned_Date__c = Date.today().addDays(-1),
                Score__c = 92
            ),
            new Employee_Training__c(
                Employee__c = unlinkedEmployee.Id,
                Training__c = training.Id,
                Training_Status__c = 'Assigned',
                Assigned_Date__c = Date.today()
            )
        };
    }

    @IsTest
    static void getMyTrainingsReturnsOnlyCurrentEmployeesAssignments() {
        Test.startTest();
        List<Employee_Training__c> assignments =
            MyTrainingController.getMyTrainings();
        Test.stopTest();

        System.assertEquals(1, assignments.size());
        System.assertEquals('My Training Test Course', assignments[0].Training__r.Name);
        System.assertEquals('MY-TRAIN-COURSE', assignments[0].Training__r.Training_code__c);
        System.assertEquals('Technical', assignments[0].Training__r.Training_Category__c);
        System.assertEquals(8.0, assignments[0].Training__r.Duration_Hours__c);
        System.assertEquals(true, assignments[0].Training__r.Active__c);
        System.assertEquals('Assigned', assignments[0].Training_Status__c);
        System.assertEquals(Date.today().addDays(-1), assignments[0].Assigned_Date__c);
        System.assertEquals(92.0, assignments[0].Score__c);
    }

    @IsTest
    static void updateToInProgressDoesNotChangeScore() {
        Employee_Training__c assignment = getCurrentEmployeeAssignment();

        Test.startTest();
        MyTrainingController.updateMyTraining(
            assignment.Id, 'In Progress', null
        );
        Test.stopTest();

        Employee_Training__c updated = [
            SELECT Training_Status__c, Completion_Date__c, Score__c
            FROM Employee_Training__c
            WHERE Id = :assignment.Id
        ];
        System.assertEquals('In Progress', updated.Training_Status__c);
        System.assertEquals(null, updated.Completion_Date__c);
        System.assertEquals(92.0, updated.Score__c);
    }

    @IsTest
    static void updateToCompletedRequiresAndSavesDate() {
        Employee_Training__c assignment = getCurrentEmployeeAssignment();
        Date completedOn = Date.today();

        Test.startTest();
        MyTrainingController.updateMyTraining(
            assignment.Id, 'Completed', completedOn
        );
        Test.stopTest();

        Employee_Training__c updated = [
            SELECT Training_Status__c, Completion_Date__c, Score__c
            FROM Employee_Training__c
            WHERE Id = :assignment.Id
        ];
        System.assertEquals('Completed', updated.Training_Status__c);
        System.assertEquals(completedOn, updated.Completion_Date__c);
        System.assertEquals(92.0, updated.Score__c);
    }

    @IsTest
    static void rejectsAssignmentOwnedByAnotherEmployee() {
        Employee_Training__c otherAssignment = [
            SELECT Id
            FROM Employee_Training__c
            WHERE Employee__r.Employee_code__c = 'MY-TRAIN-EMP-02'
            LIMIT 1
        ];
        Boolean errorThrown = false;

        try {
            MyTrainingController.updateMyTraining(
                otherAssignment.Id, 'Completed', Date.today()
            );
        } catch (AuraHandledException ex) {
            errorThrown = true;
        }

        System.assertEquals(true, errorThrown);
    }

    @IsTest
    static void rejectsInvalidStatusAndMissingCompletionDate() {
        Employee_Training__c assignment = getCurrentEmployeeAssignment();
        System.assertEquals(
            true,
            updateThrows(assignment.Id, 'Assigned', null),
            'Employees cannot set an unsupported status.'
        );
        System.assertEquals(
            true,
            updateThrows(assignment.Id, 'Completed', null),
            'Completed training must have a completion date.'
        );
        System.assertEquals(
            true,
            updateThrows(assignment.Id, 'Completed', Date.today().addDays(1)),
            'Completed training cannot have a future completion date.'
        );
        System.assertEquals(
            true,
            updateThrows(null, 'In Progress', null),
            'An assignment ID is required.'
        );
    }

    @IsTest
    static void rejectsUserWithoutLinkedEmployee() {
        Employee__c linkedEmployee = [
            SELECT Id, Salesforce_user__c
            FROM Employee__c
            WHERE Salesforce_user__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        linkedEmployee.Salesforce_user__c = null;
        update linkedEmployee;

        Boolean errorThrown = false;
        try {
            MyTrainingController.getMyTrainings();
        } catch (AuraHandledException ex) {
            errorThrown = true;
        }

        System.assertEquals(true, errorThrown);
    }

    @IsTest
    static void rejectsUserLinkedToMultipleEmployees() {
        Employee__c currentEmployee = [
            SELECT department__c
            FROM Employee__c
            WHERE Salesforce_user__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        insert new Employee__c(
            Name = 'Duplicate Mapping Test Employee',
            Employee_code__c = 'MY-TRAIN-EMP-03',
            Email__c = 'duplicate.mapping@example.com',
            Phone__c = '555-010-2003',
            Date_of_joining__c = Date.today(),
            Designation__c = 'Analyst',
            Employment_Status__c = 'Active',
            department__c = currentEmployee.department__c,
            Salesforce_user__c = UserInfo.getUserId()
        );

        Boolean errorThrown = false;
        try {
            MyTrainingController.getMyTrainings();
        } catch (AuraHandledException ex) {
            errorThrown = true;
        }

        System.assertEquals(true, errorThrown);
    }

    private static Employee_Training__c getCurrentEmployeeAssignment() {
        return [
            SELECT Id
            FROM Employee_Training__c
            WHERE Employee__r.Salesforce_user__c = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    private static Boolean updateThrows(
        Id assignmentId,
        String status,
        Date completionDate
    ) {
        try {
            MyTrainingController.updateMyTraining(
                assignmentId, status, completionDate
            );
            return false;
        } catch (AuraHandledException ex) {
            return true;
        }
    }
}
