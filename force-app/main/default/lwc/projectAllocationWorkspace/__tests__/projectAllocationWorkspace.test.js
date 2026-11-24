import { createElement } from '@lwc/engine-dom';
import { createApexTestWireAdapter as mockCreateApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import ProjectAllocationWorkspace from 'c/projectAllocationWorkspace';
import getProjectAllocations from '@salesforce/apex/ProjectWorkspaceController.getProjectAllocations';
import assignEmployeeToProject from '@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject';

jest.mock('@salesforce/apex/ProjectWorkspaceController.getProjectAllocations', () => ({
    default: mockCreateApexTestWireAdapter(jest.fn())
}), { virtual: true });
jest.mock('@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe('c-project-allocation-workspace', () => {
    afterEach(() => { document.body.innerHTML = ''; jest.clearAllMocks(); });

    it('maps allocation records to employee and project links', async () => {
        const element = createElement('c-project-allocation-workspace', { is: ProjectAllocationWorkspace });
        document.body.appendChild(element);
        getProjectAllocations.emit([{
            Id: 'allocation-1', Employee__c: 'employee-1', Project__c: 'project-1',
            Employee__r: { Name: 'Alex' },
            Project__r: { Name: 'Atlas', Project_Code__c: 'AT-1', Client_Name__c: 'Northwind' }
        }]);
        await flushPromises();
        const row = element.shadowRoot.querySelector('lightning-datatable').data[0];
        expect(row.employeeUrl).toBe('/lightning/r/Employee__c/employee-1/view');
        expect(row.projectUrl).toBe('/lightning/r/Project__c/project-1/view');
        expect(row.clientName).toBe('Northwind');
    });

    it('submits both selected record IDs', async () => {
        assignEmployeeToProject.mockResolvedValue('allocation-2');
        const element = createElement('c-project-allocation-workspace', { is: ProjectAllocationWorkspace });
        document.body.appendChild(element);
        const pickers = element.shadowRoot.querySelectorAll('lightning-record-picker');
        pickers[0].dispatchEvent(new CustomEvent('change', { detail: { recordId: 'employee-2' } }));
        pickers[1].dispatchEvent(new CustomEvent('change', { detail: { recordId: 'project-2' } }));
        await flushPromises();
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();
        expect(assignEmployeeToProject).toHaveBeenCalledWith(expect.objectContaining({
            employeeId: 'employee-2', projectId: 'project-2'
        }));
    });
});
