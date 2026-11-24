@IsTest
private class ProjectPortfolioControllerTest {
    @TestSetup
    static void createTestProjects() {
        insert new List<Project__c>{
            new Project__c(
                Name = 'Portfolio Test Beta',
                Project_Code__c = 'PORT-02',
                Project_Status__c = 'Planned',
                Client_Name__c = 'Client Beta',
                Start_Date__c = Date.today().addDays(10),
                End_Date__c = Date.today().addDays(40)
            ),
            new Project__c(
                Name = 'Portfolio Test Alpha',
                Project_Code__c = 'PORT-01',
                Project_Status__c = 'In Progress',
                Client_Name__c = 'Client Alpha',
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(30)
            )
        };
    }

    @IsTest
    static void returnsProjectsWithPortfolioFieldsInNameOrder() {
        Test.startTest();
        List<Project__c> projects = ProjectPortfolioController.getProjects();
        Test.stopTest();

        System.assertEquals(2, projects.size());
        System.assertEquals('Portfolio Test Alpha', projects[0].Name);
        System.assertEquals('PORT-01', projects[0].Project_Code__c);
        System.assertEquals('In Progress', projects[0].Project_Status__c);
        System.assertEquals('Client Alpha', projects[0].Client_Name__c);
        System.assertEquals(Date.today(), projects[0].Start_Date__c);
        System.assertEquals(Date.today().addDays(30), projects[0].End_Date__c);
    }
}
