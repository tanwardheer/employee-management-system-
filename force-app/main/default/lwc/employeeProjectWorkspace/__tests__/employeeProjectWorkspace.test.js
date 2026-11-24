import { createElement } from '@lwc/engine-dom';
import { createApexTestWireAdapter as mockCreateApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import EmployeeProjectWorkspace from 'c/employeeProjectWorkspace';
import getEmployeeProjects from '@salesforce/apex/ProjectWorkspaceController.getEmployeeProjects';
import assignEmployeeToProject from '@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject';

jest.mock('@salesforce/apex/ProjectWorkspaceController.getEmployeeProjects', () => ({
    default: mockCreateApexTestWireAdapter(jest.fn())
}), { virtual: true });
jest.mock('@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe('c-employee-project-workspace', () => {
    afterEach(() => { document.body.innerHTML = ''; jest.clearAllMocks(); });

    it('maps an employee allocation into a project link row', async () => {
        const element = createElement('c-employee-project-workspace', { is: EmployeeProjectWorkspace });
        element.recordId = 'employee-1';
        document.body.appendChild(element);
        getEmployeeProjects.emit([{
            Id: 'allocation-1', Project__c: 'project-1',
            Project__r: { Name: 'Atlas', Project_Code__c: 'AT-1', Project_Status__c: 'Active' }
        }]);
        await flushPromises();
        const row = element.shadowRoot.querySelector('lightning-datatable').data[0];
        expect(row.projectName).toBe('Atlas');
        expect(row.projectUrl).toBe('/lightning/r/Project__c/project-1/view');
    });

    it('rejects reversed allocation dates before calling Apex', async () => {
        const element = createElement('c-employee-project-workspace', { is: EmployeeProjectWorkspace });
        element.recordId = 'employee-2';
        document.body.appendChild(element);
        const picker = element.shadowRoot.querySelector('lightning-record-picker');
        picker.dispatchEvent(new CustomEvent('change', { detail: { recordId: 'project-2' } }));
        const dates = element.shadowRoot.querySelectorAll('lightning-input');
        dates[0].dispatchEvent(new CustomEvent('change', { detail: { value: '2026-11-20' } }));
        dates[1].dispatchEvent(new CustomEvent('change', { detail: { value: '2026-11-10' } }));
        await flushPromises();
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();
        expect(assignEmployeeToProject).not.toHaveBeenCalled();
    });
});
