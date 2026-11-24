public with sharing class ProjectPortfolioController {
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getProjects() {
        return [
            SELECT Id, Name, Project_Code__c, Project_Status__c, Client_Name__c,
                Start_Date__c, End_Date__c
            FROM Project__c
            WITH USER_MODE
            ORDER BY Name
            LIMIT 500
        ];
    }
}
