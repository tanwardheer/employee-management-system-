import { createElement } from '@lwc/engine-dom';
import { createApexTestWireAdapter as mockCreateApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import ProjectPortfolio from 'c/projectPortfolio';
import getProjects from '@salesforce/apex/ProjectPortfolioController.getProjects';

jest.mock('@salesforce/apex/ProjectPortfolioController.getProjects', () => ({
    default: mockCreateApexTestWireAdapter(jest.fn())
}), { virtual: true });

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe('c-project-portfolio', () => {
    afterEach(() => { document.body.innerHTML = ''; jest.clearAllMocks(); });

    it('filters project rows by search and status', async () => {
        const element = createElement('c-project-portfolio', { is: ProjectPortfolio });
        document.body.appendChild(element);
        getProjects.emit([
            { Id: 'p-1', Name: 'Atlas', Project_Code__c: 'AT-1', Project_Status__c: 'Active', Client_Name__c: 'Northwind' },
            { Id: 'p-2', Name: 'Beacon', Project_Code__c: 'BE-2', Project_Status__c: 'Planned', Client_Name__c: 'Contoso' }
        ]);
        await flushPromises();
        const search = element.shadowRoot.querySelector('lightning-input');
        search.value = 'north';
        search.dispatchEvent(new CustomEvent('change'));
        await flushPromises();
        expect(element.shadowRoot.querySelector('lightning-datatable').data).toHaveLength(1);
        expect(element.shadowRoot.querySelector('lightning-datatable').data[0].recordUrl)
            .toBe('/lightning/r/Project__c/p-1/view');
    });

    it('shows a load error without project rows', async () => {
        const element = createElement('c-project-portfolio', { is: ProjectPortfolio });
        document.body.appendChild(element);
        getProjects.error();
        await flushPromises();
        expect(element.shadowRoot.querySelector('[role="alert"]')).not.toBeNull();
    });
});
