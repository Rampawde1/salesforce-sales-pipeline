@isTest
public class OpportunityHelperTest {

    static Opportunity makeOpp(String stage) {
        return new Opportunity(
            Name      = 'Test Opp',
            StageName = stage,
            CloseDate = Date.today().addDays(30),
            Amount    = 100000
        );
    }

    // Test 1: Stage date set on insert
    @isTest
    static void testStageDateOnInsert() {
        Opportunity o = makeOpp('Prospecting');
        Test.startTest();
        insert o;
        Test.stopTest();
        Opportunity result = [
            SELECT Stage_Changed_Date__c
            FROM   Opportunity WHERE Id = :o.Id
        ];
        System.assertEquals(Date.today(),
            result.Stage_Changed_Date__c,
            'Stage date should be today on insert');
    }

    // Test 2: Stage date updates when stage changes
    @isTest
    static void testStageDateOnStageChange() {
        Opportunity o = makeOpp('Prospecting');
        insert o;
        Test.startTest();
        o.StageName = 'Qualification';
        update o;
        Test.stopTest();
        Opportunity result = [
            SELECT Stage_Changed_Date__c, StageName
            FROM   Opportunity WHERE Id = :o.Id
        ];
        System.assertEquals('Qualification',
            result.StageName, 'Stage should be updated');
        System.assertEquals(Date.today(),
            result.Stage_Changed_Date__c,
            'Stage date should refresh on change');
    }

    // Test 3: Loss reason clears when re-opened
    @isTest
    static void testLossReasonClearsOnReopen() {
        Opportunity o = makeOpp('Closed Lost');
        o.Loss_Reason__c = 'Price';
        insert o;
        Test.startTest();
        o.StageName     = 'Prospecting';
        o.Loss_Reason__c = 'Price';
        update o;
        Test.stopTest();
        Opportunity result = [
            SELECT Loss_Reason__c
            FROM   Opportunity WHERE Id = :o.Id
        ];
        System.assertEquals(null, result.Loss_Reason__c,
            'Loss reason should clear when re-opened');
    }

    // Test 4: Close date error for past date on open deal
    @isTest
    static void testCloseDateValidation() {
        Opportunity o = makeOpp('Prospecting');
        insert o;
        Test.startTest();
        o.CloseDate = Date.today().addDays(-10);
        try {
            update o;
            System.assert(false,
                'Should have thrown DmlException');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Close Date is in the past'),
                'Error message should mention close date'
            );
        }
        Test.stopTest();
    }

    // Test 5: Chatter post on stage change
    @isTest
    static void testChatterPost() {
        Opportunity o = makeOpp('Prospecting');
        insert o;
        Test.startTest();
        o.StageName = 'Closed Won';
        update o;
        Test.stopTest();
        List<FeedItem> feeds = [
            SELECT Body FROM FeedItem
            WHERE ParentId = :o.Id
        ];
        System.assert(!feeds.isEmpty(),
            'Chatter post should exist');
        System.assert(
            feeds[0].Body.contains('Closed Won'),
            'Post should mention new stage');
    }

    // Test 6: No date change when stage unchanged
    @isTest
    static void testNoDateChangeIfSameStage() {
        Opportunity o = makeOpp('Qualification');
        insert o;
        Date original = [
            SELECT Stage_Changed_Date__c
            FROM Opportunity WHERE Id = :o.Id
        ].Stage_Changed_Date__c;
        Test.startTest();
        o.Amount = 999999;
        update o; // Same stage, only Amount changes
        Test.stopTest();
        Opportunity result = [
            SELECT Stage_Changed_Date__c
            FROM Opportunity WHERE Id = :o.Id
        ];
        System.assertEquals(original,
            result.Stage_Changed_Date__c,
            'Date should not change if stage unchanged');
    }
}