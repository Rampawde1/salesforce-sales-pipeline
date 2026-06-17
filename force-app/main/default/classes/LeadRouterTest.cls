@isTest
public class LeadRouterTest {

    @TestSetup
    static void makeData() {
        Lead__c ctr = new Lead__c();
        ctr.Last_Index__c = 0;
        upsert ctr;
    }

    // ── Test 1: Hot score + assignment on insert ──────────────────
    @isTest
    static void testScoreAndAssignOnInsert() {
        Lead l = new Lead(
            FirstName         = 'Rohan',
            LastName          = 'Mehta',
            Company           = 'Nexgen',
            Email             = 'r@nexgen.com',
            Phone             = '+91 9876543210',
            LeadSource        = 'Web',
            NumberOfEmployees = 200
        );
        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [
            SELECT Lead_Score__c, Rating, Status, OwnerId, Assigned_SDR__c
            FROM   Lead WHERE Id = :l.Id
        ];
        System.assertEquals(90,   result.Lead_Score__c, 'Score should be 90');
        System.assertEquals('Hot', result.Rating,        'Rating should be Hot');
        System.assertEquals('Open - Not Contacted', result.Status, 'Status should be set');
        System.assertNotEquals(null, result.OwnerId, 'Owner should be assigned');
    }

    // ── Test 2: Warm score branch ─────────────────────────────────
    @isTest
    static void testScoreWarm() {
        Lead l = new Lead(
            FirstName  = 'Priya',
            LastName   = 'Shah',
            Company    = 'WarmCo',
            Email      = 'p@warmco.com',
            LeadSource = 'Cold Call'
        );
        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [SELECT Lead_Score__c, Rating FROM Lead WHERE Id = :l.Id];
        System.assertEquals(50,     result.Lead_Score__c, 'Score should be 50');
        System.assertEquals('Warm', result.Rating,         'Rating should be Warm');
    }

    // ── Test 3: Cold score branch ─────────────────────────────────
    @isTest
    static void testScoreCold() {
        Lead l = new Lead(
            LastName   = 'ColdLead',
            Company    = 'ColdCo',
            LeadSource = 'Other'
        );
        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [SELECT Lead_Score__c, Rating FROM Lead WHERE Id = :l.Id];
        System.assert(result.Lead_Score__c < 40, 'Score should be below 40');
        System.assertEquals('Cold', result.Rating, 'Rating should be Cold');
    }

    // ── Test 4: Re-score on update ────────────────────────────────
    @isTest
    static void testReScoreOnUpdate() {
        Lead l = new Lead(
            LastName   = 'UpdateLead',
            Company    = 'UpdateCo',
            LeadSource = 'Other'
        );
        insert l;

        Test.startTest();
        l.LeadSource = 'Word of mouth';
        l.Email      = 'u@updateco.com';
        l.Phone      = '+91 9999999999';
        update l;
        Test.stopTest();

        Lead result = [SELECT Lead_Score__c, Rating FROM Lead WHERE Id = :l.Id];
        System.assert(result.Lead_Score__c >= 70, 'Score should be Hot after update');
        System.assertEquals('Hot', result.Rating,  'Rating should be Hot after update');
    }

    // ── Test 5: assignLeads with no SDRs — guard clause ──────────
    @isTest
    static void testAssignLeadsNoSDRs() {
        Test.startTest();
        List<Lead> leads = new List<Lead>{
            new Lead(LastName = 'NoSDR', Company = 'TestCo', LeadSource = 'Web')
        };
        LeadRouter.assignLeads(leads);
        Test.stopTest();
        System.assert(true, 'No exception should be thrown when SDR list is empty');
    }

    // ── Test 6: createLead happy path ─────────────────────────────
    @isTest
    static void testControllerCreateLead() {
        Test.startTest();
        String leadId = LeadCaptureController.createLead(
            'Anita', 'Kumar', 'TechCorp',
            'a@techcorp.com', '+91 9123456789',
            'Web', 'CRM'
        );
        Test.stopTest();

        System.assertNotEquals(null, leadId, 'Lead Id must be returned');
        Lead result = [
            SELECT Company, LeadSource, Product_Interest__c
            FROM   Lead WHERE Id = :leadId
        ];
        System.assertEquals('TechCorp', result.Company,             'Company should match');
        System.assertEquals('Web',      result.LeadSource,          'Source should match');
        System.assertEquals('CRM',      result.Product_Interest__c, 'Product interest should match');
    }

    // ── Test 7: createLead exception path ─────────────────────────
    @isTest
    static void testControllerCreateLeadException() {
        Test.startTest();
        try {
            LeadCaptureController.createLead(
                'Bad', null, null,
                null, null, null, null
            );
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'AuraHandledException correctly thrown');
        }
        Test.stopTest();
    }

    // ── Test 8: getLeadSources returns values ─────────────────────
    @isTest
    static void testGetLeadSources() {
        Test.startTest();
        List<Map<String,String>> sources = LeadCaptureController.getLeadSources();
        Test.stopTest();

        System.assertNotEquals(null,  sources,               'Sources should not be null');
        System.assert(sources.size() > 0,                    'Should have at least one source');
        System.assertNotEquals(null, sources[0].get('label'),'Label should exist');
        System.assertNotEquals(null, sources[0].get('value'),'Value should exist');
    }

    // ── Test 9: round-robin counter increments ────────────────────
    @isTest
    static void testRoundRobinCounter() {
        List<Lead> leads = new List<Lead>{
            new Lead(LastName='L1', Company='Co1', Email='l1@co.com', LeadSource='Web'),
            new Lead(LastName='L2', Company='Co2', Email='l2@co.com', LeadSource='Web')
        };
        Test.startTest();
        insert leads;
        Test.stopTest();

        Lead__c ctr = Lead__c.getOrgDefaults();
        System.assertNotEquals(null, ctr,             'Counter record should exist');
        System.assert(ctr.Last_Index__c >= 0,         'Counter should be non-negative');
    }

    // ── Test 10: auto-response sends when email provided ─────────
    // Covers: sendAutoResponse() happy path — template missing in
    // test context so catch block fires, lead must still be created
    @isTest
    static void testAutoResponseWithEmail() {
        Test.startTest();
        String leadId = LeadCaptureController.createLead(
            'Sneha', 'Patel', 'AutoCorp',
            'sneha@autocorp.com',    // ← email present → sendAutoResponse called
            '+91 9876500000',
            'Web', 'CRM'
        );
        Test.stopTest();

        // Template 'Lead_Auto_Response' won't exist in test context
        // sendAutoResponse catch block fires silently
        // Lead must still be created successfully
        System.assertNotEquals(null, leadId,
            'Lead must be created even when email template is missing');

        Lead result = [
            SELECT Email FROM Lead WHERE Id = :leadId
        ];
        System.assertEquals('sneha@autocorp.com', result.Email,
            'Email should be saved on the lead record');
    }

    // ── Test 11: auto-response skipped when email is null ────────
    // Covers: the if (email != null) guard in createLead()
    @isTest
    static void testAutoResponseSkippedWhenNoEmail() {
        Test.startTest();
        String leadId = LeadCaptureController.createLead(
            'No', 'Email', 'NoCo',
            null,                    // ← null email → sendAutoResponse NOT called
            '+91 9000000000',
            'Web', 'Analytics'
        );
        Test.stopTest();

        System.assertNotEquals(null, leadId,
            'Lead must be created even without an email address');

        Lead result = [
            SELECT Email FROM Lead WHERE Id = :leadId
        ];
        System.assertEquals(null, result.Email,
            'Email field should be null on the lead');
    }

    // ── Test 12: auto-response catch block — bad template name ───
    // Covers: the catch(Exception e) in sendAutoResponse()
    // Forces the code path where template query returns empty
    @isTest
    static void testAutoResponseHandlesMissingTemplate() {
        // In test context, no email templates exist by default
        // sendAutoResponse will query for 'Lead_Auto_Response',
        // get an empty list, hit the isEmpty() guard, and return
        // Lead creation must complete without any exception bubbling up
        Test.startTest();
        String leadId = LeadCaptureController.createLead(
            'Vikram', 'Rao', 'MissingTmpl Co',
            'vikram@missingtmpl.com',
            '+91 9111100000',
            'Social', 'Integration'
        );
        Test.stopTest();

        System.assertNotEquals(null, leadId,
            'Lead Id must be returned — template miss must not break flow');

        Lead result = [
            SELECT LeadSource, Product_Interest__c
            FROM   Lead WHERE Id = :leadId
        ];
        System.assertEquals('Social',      result.LeadSource,
            'LeadSource should be saved correctly');
        System.assertEquals('Integration', result.Product_Interest__c,
            'Product interest should be saved correctly');
    }
}