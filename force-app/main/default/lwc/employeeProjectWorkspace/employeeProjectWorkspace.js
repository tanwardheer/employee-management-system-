import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getEmployeeProjects from '@salesforce/apex/ProjectWorkspaceController.getEmployeeProjects';
import assignEmployeeToProject from '@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    {
        label: 'Project',
        fieldName: 'projectUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'projectName' }, target: '_self' }
    },
    { label: 'Project Code', fieldName: 'projectCode', type: 'text' },
    { label: 'Status', fieldName: 'projectStatus', type: 'text' },
    { label: 'Client', fieldName: 'clientName', type: 'text' },
    { label: 'Allocation Start', fieldName: 'allocationStartDate', type: 'date-local' },
    { label: 'Allocation End', fieldName: 'allocationEndDate', type: 'date-local' }
];

export default class EmployeeProjectWorkspace extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    projectId;
    allocationStartDate;
    allocationEndDate;
    isSaving = false;
    projectRows = [];
    loadError;
    projectsResult;

    projectDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Project_Code__c']
    };

    projectMatchingInfo = {
        primaryField: { fieldPath: 'Name', mode: 'contains' },
        additionalFields: [{ fieldPath: 'Project_Code__c', mode: 'contains' }]
    };

    @wire(getEmployeeProjects, { employeeId: '$recordId' })
    wiredEmployeeProjects(result) {
        this.projectsResult = result;
        if (result.data) {
            this.projectRows = result.data.map((allocation) => ({
                allocationId: allocation.Id,
                projectUrl: `/lightning/r/Project__c/${allocation.Project__c}/view`,
                projectName: allocation.Project__r?.Name,
                projectCode: allocation.Project__r?.Project_Code__c,
                projectStatus: allocation.Project__r?.Project_Status__c,
                clientName: allocation.Project__r?.Client_Name__c,
                allocationStartDate: allocation.Allocation_Start_Date__c,
                allocationEndDate: allocation.Allocation_End_Date__c
            }));
            this.loadError = undefined;
        } else if (result.error) {
            this.projectRows = [];
            this.loadError = this.getErrorMessage(result.error);
        }
    }

    get hasProjectRows() {
        return this.projectRows.length > 0;
    }

    get projectCount() {
        return this.projectRows.length;
    }

    get isAssignDisabled() {
        return this.isSaving || !this.projectId || !this.recordId;
    }

    get hasLoadError() {
        return Boolean(this.loadError);
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
                employeeId: this.recordId,
                allocationStartDate: this.allocationStartDate || null,
                allocationEndDate: this.allocationEndDate || null
            });

            this.showToast('Project assigned', 'The employee’s project list has been updated.', 'success');
            this.projectId = undefined;
            this.allocationStartDate = undefined;
            this.allocationEndDate = undefined;
            await refreshApex(this.projectsResult);
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
