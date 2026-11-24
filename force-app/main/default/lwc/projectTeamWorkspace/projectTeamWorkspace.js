import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getProjectTeam from '@salesforce/apex/ProjectWorkspaceController.getProjectTeam';
import assignEmployeeToProject from '@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Employee', fieldName: 'employeeName', type: 'text' },
    { label: 'Allocation Number', fieldName: 'allocationNumber', type: 'text' },
    { label: 'Start Date', fieldName: 'allocationStartDate', type: 'date-local' },
    { label: 'End Date', fieldName: 'allocationEndDate', type: 'date-local' }
];

export default class ProjectTeamWorkspace extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    employeeId;
    allocationStartDate;
    allocationEndDate;
    isSaving = false;
    teamRows = [];
    loadError;
    teamResult;

    employeeFilter = {
        criteria: [
            {
                fieldPath: 'Employment_Status__c',
                operator: 'eq',
                value: 'Active'
            }
        ]
    };

    employeeDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Employee_code__c']
    };

    employeeMatchingInfo = {
        primaryField: { fieldPath: 'Name', mode: 'contains' },
        additionalFields: [{ fieldPath: 'Employee_code__c', mode: 'contains' }]
    };

    @wire(getProjectTeam, { projectId: '$recordId' })
    wiredProjectTeam(result) {
        this.teamResult = result;
        if (result.data) {
            this.teamRows = result.data;
            this.loadError = undefined;
        } else if (result.error) {
            this.teamRows = [];
            this.loadError = this.getErrorMessage(result.error);
        }
    }

    get hasTeamRows() {
        return this.teamRows.length > 0;
    }

    get teamCount() {
        return this.teamRows.length;
    }

    get isAssignDisabled() {
        return this.isSaving || !this.employeeId || !this.recordId;
    }

    get hasLoadError() {
        return Boolean(this.loadError);
    }

    handleEmployeeChange(event) {
        this.employeeId = event.detail.recordId;
    }

    handleStartDateChange(event) {
        this.allocationStartDate = event.detail.value;
    }

    handleEndDateChange(event) {
        this.allocationEndDate = event.detail.value;
    }

    async handleAssign() {
        const dateInputs = this.template.querySelectorAll('lightning-input[type="date"]');
        const datesAreValid = [...dateInputs].every((input) => input.reportValidity());
        if (!datesAreValid) {
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
                projectId: this.recordId,
                employeeId: this.employeeId,
                allocationStartDate: this.allocationStartDate || null,
                allocationEndDate: this.allocationEndDate || null
            });

            this.showToast('Employee assigned', 'The project team has been updated.', 'success');
            this.employeeId = undefined;
            this.allocationStartDate = undefined;
            this.allocationEndDate = undefined;
            await refreshApex(this.teamResult);
        } catch (error) {
            this.showToast('Could not assign employee', this.getErrorMessage(error), 'error');
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
