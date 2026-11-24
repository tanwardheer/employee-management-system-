import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getProjectAllocations from '@salesforce/apex/ProjectWorkspaceController.getProjectAllocations';
import assignEmployeeToProject from '@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    {
        label: 'Employee',
        fieldName: 'employeeUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'employeeName' }, target: '_self' }
    },
    {
        label: 'Project',
        fieldName: 'projectUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'projectName' }, target: '_self' }
    },
    { label: 'Project Code', fieldName: 'projectCode', type: 'text' },
    { label: 'Client', fieldName: 'clientName', type: 'text' },
    { label: 'Status', fieldName: 'projectStatus', type: 'text' },
    { label: 'Start Date', fieldName: 'allocationStartDate', type: 'date-local' },
    { label: 'End Date', fieldName: 'allocationEndDate', type: 'date-local' }
];

export default class ProjectAllocationWorkspace extends LightningElement {
    columns = COLUMNS;
    employeeId;
    projectId;
    allocationStartDate;
    allocationEndDate;
    isSaving = false;
    allocationRows = [];
    loadError;
    allocationsResult;

    employeeDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Employee_code__c']
    };

    employeeMatchingInfo = {
        primaryField: { fieldPath: 'Name', mode: 'contains' },
        additionalFields: [{ fieldPath: 'Employee_code__c', mode: 'contains' }]
    };

    activeEmployeeFilter = {
        criteria: [
            { fieldPath: 'Employment_Status__c', operator: 'eq', value: 'Active' }
        ]
    };

    projectDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Project_Code__c']
    };

    projectMatchingInfo = {
        primaryField: { fieldPath: 'Name', mode: 'contains' },
        additionalFields: [{ fieldPath: 'Project_Code__c', mode: 'contains' }]
    };

    @wire(getProjectAllocations)
    wiredAllocations(result) {
        this.allocationsResult = result;
        if (result.data) {
            this.allocationRows = result.data.map((allocation) => ({
                allocationId: allocation.Id,
                employeeUrl: `/lightning/r/Employee__c/${allocation.Employee__c}/view`,
                employeeName: allocation.Employee__r?.Name,
                projectUrl: `/lightning/r/Project__c/${allocation.Project__c}/view`,
                projectName: allocation.Project__r?.Name,
                projectCode: allocation.Project__r?.Project_Code__c,
                clientName: allocation.Project__r?.Client_Name__c,
                projectStatus: allocation.Project__r?.Project_Status__c,
                allocationStartDate: allocation.Allocation_Start_Date__c,
                allocationEndDate: allocation.Allocation_End_Date__c
            }));
            this.loadError = undefined;
        } else if (result.error) {
            this.allocationRows = [];
            this.loadError = this.getErrorMessage(result.error);
        }
    }

    get allocationCount() {
        return this.allocationRows.length;
    }

    get hasAllocations() {
        return this.allocationRows.length > 0;
    }

    get hasLoadError() {
        return Boolean(this.loadError);
    }

    get isAssignDisabled() {
        return this.isSaving || !this.employeeId || !this.projectId;
    }

    handleEmployeeChange(event) {
        this.employeeId = event.detail.recordId;
    }

    handleProjectChange(event) {
        this.projectId = event.detail.recordId;
    }

    handleStartDateChange(event) {
        this.allocationStartDate = event.detail.value;
    }

    handleEndDateChange(event) {
        this.allocationEndDate = event.detail.value;
    }

    async handleAssign() {
        const dateInputs = this.template.querySelectorAll('lightning-input[type="date"]');
        if (![...dateInputs].every((input) => input.reportValidity())) {
            return;
        }

        if (
            this.allocationStartDate &&
            this.allocationEndDate &&
            this.allocationEndDate < this.allocationStartDate
        ) {
            this.showToast(
                'Check the dates',
                'The allocation end date cannot be before its start date.',
                'error'
            );
            return;
        }

        this.isSaving = true;
        try {
            await assignEmployeeToProject({
                projectId: this.projectId,
                employeeId: this.employeeId,
                allocationStartDate: this.allocationStartDate || null,
                allocationEndDate: this.allocationEndDate || null
            });

            this.showToast(
                'Project assigned',
                'The employee has been added to the project.',
                'success'
            );
            this.employeeId = undefined;
            this.projectId = undefined;
            this.allocationStartDate = undefined;
            this.allocationEndDate = undefined;
            await refreshApex(this.allocationsResult);
        } catch (error) {
            this.showToast('Could not assign project', this.getErrorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'Something went wrong. Try again.';
    }
}
