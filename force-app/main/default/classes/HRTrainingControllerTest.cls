@IsTest
private class HRTrainingControllerTest {
    @TestSetup
    static void createTestData() {
        departement__c department = new departement__c(
            Name = 'HR Training Test Department',
            Department_Code__c = 'HR-TRAIN-DEPT'
        );
        insert department;

        Employee__c employee = new Employee__c(
            Name = 'HR Test Employee',
            Employee_code__c = 'HR-TRAIN-EMP-01',
            Email__c = 'hr.training.employee@example.com',
            Phone__c = '555-010-3001',
            Date_of_joining__c = Date.today(),
            Designation__c = 'Analyst',
            Employment_Status__c = 'Active',
            department__c = department.Id,
            Salesforce_user__c = UserInfo.getUserId()
        );
        insert employee;

        Training__c training = new Training__c(
            Name = 'HR Test Training',
            Training_code__c = 'HR-TRAIN-COURSE',
            Training_Category__c = 'Technical',
            Duration_Hours__c = 6,
            Active__c = true
        );
        insert training;

        insert new Employee_Training__c(
            Employee__c = employee.Id,
            Training__c = training.Id,
            Training_Status__c = 'Completed',
            Assigned_Date__c = Date.today().addDays(-7),
            Completion_Date__c = Date.today().addDays(-1),
            Score__c = 80
        );

        // Setup-object changes are inside runAs to keep test data creation isolated.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile currentProfile = [
                SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId()
            ];
            List<User> testUsers = new List<User>{
                new User(
                    Alias = 'hrtest',
                    Email = 'hr.permission@example.com',
                    EmailEncodingKey = 'UTF-8',
                    LastName = 'HR Test User',
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    ProfileId = currentProfile.Id,
                    TimeZoneSidKey = 'America/Los_Angeles',
                    Username = 'hr.permission.' + UserInfo.getOrganizationId() + '@example.com'
                ),
                new User(
                Alias = 'nohruser',
                Email = 'no.hr.permission@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'No HR Permission',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = currentProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'no.hr.permission.' + UserInfo.getOrganizationId() + '@example.com'
                )
            };
            insert testUsers;

            PermissionSet hrPermissionSet = [
                SELECT Id FROM PermissionSet WHERE Name = 'HR_Training_Manager' LIMIT 1
            ];
            insert new PermissionSetAssignment(
                AssigneeId = testUsers[0].Id,
                PermissionSetId = hrPermissionSet.Id
            );
        }
    }

    @IsTest
    static void returnsFilteredAssignmentsForAuthorizedHr() {
        Employee__c employee = [
            SELECT Id FROM Employee__c WHERE Employee_code__c = 'HR-TRAIN-EMP-01'
        ];
        Training__c training = [
            SELECT Id FROM Training__c WHERE Training_code__c = 'HR-TRAIN-COURSE'
        ];

        Test.startTest();
        List<Employee_Training__c> rows;
        System.runAs(getHrUser()) {
            rows = HRTrainingController.getAssignments(
                employee.Id, training.Id, 'Completed'
            );
        }
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('HR Test Employee', rows[0].Employee__r.Name);
        System.assertEquals('HR-TRAIN-EMP-01', rows[0].Employee__r.Employee_code__c);
        System.assertEquals('HR Test Training', rows[0].Training__r.Name);
        System.assertEquals('Technical', rows[0].Training__r.Training_Category__c);
        System.assertEquals('Completed', rows[0].Training_Status__c);
    }

    @IsTest
    static void savesScoreWithoutChangingTrainingProgress() {
        Employee_Training__c assignment = getAssignment();
        HRTrainingController.ScoreUpdate change = new HRTrainingController.ScoreUpdate();
        change.assignmentId = assignment.Id;
        change.score = 95;

        Test.startTest();
        System.runAs(getHrUser()) {
            HRTrainingController.updateScores(
                new List<HRTrainingController.ScoreUpdate>{ change }
            );
        }
        Test.stopTest();

        Employee_Training__c saved = [
            SELECT Score__c, Training_Status__c, Completion_Date__c
            FROM Employee_Training__c WHERE Id = :assignment.Id
        ];
        System.assertEquals(95, saved.Score__c);
        System.assertEquals('Completed', saved.Training_Status__c);
        System.assertEquals(Date.today().addDays(-1), saved.Completion_Date__c);
    }

    @IsTest
    static void permitsClearingScore() {
        HRTrainingController.ScoreUpdate change = new HRTrainingController.ScoreUpdate();
        change.assignmentId = getAssignment().Id;
        change.score = null;

        System.runAs(getHrUser()) {
            HRTrainingController.updateScores(
                new List<HRTrainingController.ScoreUpdate>{ change }
            );
        }
        System.assertEquals(null, getAssignment().Score__c);
    }

    @IsTest
    static void rejectsScoresOutsideZeroToOneHundred() {
        Id assignmentId = getAssignment().Id;
        System.assertEquals(true, updateThrows(assignmentId, -0.01));
        System.assertEquals(true, updateThrows(assignmentId, 100.01));
    }

    @IsTest
    static void rejectsEmptyMissingAndDuplicateUpdates() {
        System.assertEquals(true, updateThrows(null));

        HRTrainingController.ScoreUpdate missingId = new HRTrainingController.ScoreUpdate();
        missingId.score = 50;
        System.assertEquals(
            true,
            updateThrows(new List<HRTrainingController.ScoreUpdate>{ missingId })
        );

        HRTrainingController.ScoreUpdate first = new HRTrainingController.ScoreUpdate();
        first.assignmentId = getAssignment().Id;
        first.score = 70;
        HRTrainingController.ScoreUpdate duplicate = new HRTrainingController.ScoreUpdate();
        duplicate.assignmentId = first.assignmentId;
        duplicate.score = 80;
        System.assertEquals(
            true,
            updateThrows(new List<HRTrainingController.ScoreUpdate>{ first, duplicate })
        );
    }

    @IsTest
    static void rejectsInvalidStatusFilter() {
        Boolean rejected = false;
        System.runAs(getHrUser()) {
            try {
                HRTrainingController.getAssignments(null, null, 'Not a status');
            } catch (AuraHandledException ex) {
                rejected = true;
            }
        }
        System.assertEquals(true, rejected);
    }

    @IsTest
    static void blocksUsersWithoutHrPermissionFromViewingAndSaving() {
        User unauthorized = [
            SELECT Id FROM User WHERE Alias = 'nohruser' LIMIT 1
        ];
        Id assignmentId = getAssignment().Id;
        Boolean readRejected = false;
        Boolean updateRejected = false;

        System.runAs(unauthorized) {
            try {
                HRTrainingController.getAssignments(null, null, 'All');
            } catch (AuraHandledException ex) {
                readRejected = true;
            }

            HRTrainingController.ScoreUpdate change = new HRTrainingController.ScoreUpdate();
            change.assignmentId = assignmentId;
            change.score = 99;
            try {
                HRTrainingController.updateScores(
                    new List<HRTrainingController.ScoreUpdate>{ change }
                );
            } catch (AuraHandledException ex) {
                updateRejected = true;
            }
        }

        System.assertEquals(true, readRejected, 'HR permission is required to view the list.');
        System.assertEquals(true, updateRejected, 'HR permission is required to save scores.');
        System.assertEquals(80, getAssignment().Score__c, 'Unauthorized score must remain unchanged.');
    }

    private static Employee_Training__c getAssignment() {
        return [
            SELECT Id, Score__c
            FROM Employee_Training__c
            WHERE Employee__r.Employee_code__c = 'HR-TRAIN-EMP-01'
            LIMIT 1
        ];
    }

    private static User getHrUser() {
        return [SELECT Id FROM User WHERE Alias = 'hrtest' LIMIT 1];
    }

    private static Boolean updateThrows(Id assignmentId, Decimal score) {
        HRTrainingController.ScoreUpdate change = new HRTrainingController.ScoreUpdate();
        change.assignmentId = assignmentId;
        change.score = score;
        return updateThrows(new List<HRTrainingController.ScoreUpdate>{ change });
    }

    private static Boolean updateThrows(List<HRTrainingController.ScoreUpdate> changes) {
        Boolean rejected = false;
        System.runAs(getHrUser()) {
            try {
                HRTrainingController.updateScores(changes);
            } catch (AuraHandledException ex) {
                rejected = true;
            }
        }
        return rejected;
    }
}
