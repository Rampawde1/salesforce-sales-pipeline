public with sharing class OpportunityHelper {

    // Called on before insert + before update
    public static void setStageDate(
        List<Opportunity> newList,
        Map<Id, Opportunity> oldMap) {

        for (Opportunity o : newList) {
            if (oldMap == null || o.StageName != oldMap.get(o.Id).StageName) {
                
                o.Stage_Changed_Date__c = Date.today();
                
                if (o.CloseDate == null)
                    o.CloseDate = Date.today().addDays(30);
                
                if (!o.StageName.startsWith('Closed'))
                    o.Loss_Reason__c = null;
            }
        }
    }

    // Called on after update — needs DML so runs after
    public static void postStageChatter(
        List<Opportunity> newList,
        Map<Id, Opportunity> oldMap) {

        List<FeedItem> posts = new List<FeedItem>();
        for (Opportunity o : newList) {
            if (o.StageName != oldMap.get(o.Id).StageName) {
                String emoji = o.StageName == 'Closed Won'  ? '🎉'
                             : o.StageName == 'Closed Lost' ? '📋' : '📈';
                FeedItem p = new FeedItem();
                p.ParentId = o.Id;
                p.Body = emoji + ' Stage: '
                    + oldMap.get(o.Id).StageName + ' → '
                    + o.StageName + ' (' + o.Probability + '%)';
                p.Type = 'TextPost';
                posts.add(p);
            }
        }
        if (!posts.isEmpty()) insert posts;
    }

    // Called on before update — warn if close date is past
    public static void validateCloseDate(
        List<Opportunity> newList) {

        for (Opportunity o : newList) {
            if (!o.StageName.startsWith('Closed')
             && o.CloseDate != null
             && o.CloseDate < Date.today()) {
                o.addError(
                    'Close Date is in the past. '
                  + 'Please update it before saving.'
                );
            }
        }
    }
}