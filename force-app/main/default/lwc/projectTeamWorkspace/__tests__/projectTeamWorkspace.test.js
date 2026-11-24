import { createElement } from '@lwc/engine-dom';
import { createApexTestWireAdapter as mockCreateApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import ProjectTeamWorkspace from 'c/projectTeamWorkspace';
import getProjectTeam from '@salesforce/apex/ProjectWorkspaceController.getProjectTeam';
import assignEmployeeToProject from '@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject';

jest.mock('@salesforce/apex/ProjectWorkspaceController.getProjectTeam', () => ({
    default: mockCreateApexTestWireAdapter(jest.fn())
}), { virtual: true });
jest.mock('@salesforce/apex/ProjectWorkspaceController.assignEmployeeToProject', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe('c-project-team-workspace', () => {
    afterEach(() => { document.body.innerHTML = ''; jest.clearAllMocks(); });

    it('shows current team rows and enables assignment after choosing an employee', async () => {
        const element = createElement('c-project-team-workspace', { is: ProjectTeamWorkspace });
        element.recordId = 'project-1';
        document.body.appendChild(element);
        getProjectTeam.emit([{ allocationId: 'allocation-1', employeeName: 'Alex' }]);
        await flushPromises();
        expect(element.shadowRoot.querySelector('lightning-datatable').data[0].employeeName).toBe('Alex');
        const picker = element.shadowRoot.querySelector('lightning-record-picker');
        picker.dispatchEvent(new CustomEvent('change', { detail: { recordId: 'employee-1' } }));
        await flushPromises();
        expect(element.shadowRoot.querySelector('lightning-button').disabled).toBe(false);
    });

    it('submits the selected employee and project ID', async () => {
        assignEmployeeToProject.mockResolvedValue('allocation-2');
        const element = createElement('c-project-team-workspace', { is: ProjectTeamWorkspace });
        element.recordId = 'project-2';
        document.body.appendChild(element);
        element.shadowRoot.querySelector('lightning-record-picker').dispatchEvent(
            new CustomEvent('change', { detail: { recordId: 'employee-2' } })
        );
        await flushPromises();
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();
        expect(assignEmployeeToProject).toHaveBeenCalledWith(expect.objectContaining({
            projectId: 'project-2', employeeId: 'employee-2'
        }));
    });
});
