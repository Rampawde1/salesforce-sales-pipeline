public with sharing class LeadRouter {

    public static void scoreLead(List<Lead> leads) {
        for (Lead l : leads) {
            Integer score = 0;
            if (l.Company != null) score += 20;
            if (l.Email   != null) score += 20;
            if (l.Phone   != null) score += 15;
            if (l.LeadSource == 'Web')               score += 20;
            if (l.LeadSource == 'Phone Inquiry')      score += 30;
            if (l.LeadSource == 'Partner Referral')   score += 10;
            if (l.LeadSource == 'Purchased List')     score += 15;
            if (l.LeadSource == 'Other')              score += 10;
            if (l.NumberOfEmployees != null
                && l.NumberOfEmployees > 100)         score += 15;

            l.Lead_Score__c = score;
            l.Rating = score >= 70 ? 'Hot'
                     : score >= 40 ? 'Warm' : 'Cold';
            if (score >= 40)
                l.Status = 'Open - Not Contacted';
        }
    }

    public static void assignLeads(List<Lead> newLeads) {
        // Step 1: try Sales profiles first
        List<User> sdrs = [
            SELECT Id, Name
            FROM   User
            WHERE  IsActive = true
            AND    Profile.Name IN (
                       'Standard User',
                       'Standard Platform User',
                       'Sales User',
                       'Custom: Sales Profile'
                   )
            AND    Id != :UserInfo.getUserId()
            ORDER BY Name
        ];

        // Step 2: fallback — any active non-Admin
        if (sdrs.isEmpty()) {
            sdrs = [
                SELECT Id, Name
                FROM   User
                WHERE  IsActive = true
                AND    Profile.Name != 'System Administrator'
                ORDER BY Name
            ];
        }

        // Step 3: last resort — everyone
        if (sdrs.isEmpty()) {
            sdrs = [
                SELECT Id, Name
                FROM   User
                WHERE  IsActive = true
                ORDER BY Name
            ];
        }

        if (sdrs.isEmpty()) return;

        // Round-robin using Custom Setting counter
        Lead__c ctr = Lead__c.getOrgDefaults();
        Integer idx = (ctr != null && ctr.Last_Index__c != null)
                      ? (Integer) ctr.Last_Index__c : 0;

        for (Lead l : newLeads) {
            Integer pos   = Math.mod(idx, sdrs.size());
            l.OwnerId         = sdrs[pos].Id;
            l.Assigned_SDR__c = sdrs[pos].Id;
            idx++;
        }

        if (ctr == null) ctr = new Lead__c();
        ctr.Last_Index__c = idx;
        upsert ctr;
    }

    // CORRECT POSITION: class-level method
    //    not nested inside assignLeads()
    public static void syncOwnerAfterInsert(
        List<Lead> newLeads) {

        List<Lead> toSync = new List<Lead>();

        for (Lead l : newLeads) {
            if (l.Assigned_SDR__c != null
                && l.OwnerId != l.Assigned_SDR__c) {
                toSync.add(new Lead(
                    Id      = l.Id,
                    OwnerId = l.Assigned_SDR__c
                ));
            }
        }

        if (!toSync.isEmpty()) {
            Database.update(toSync, false);
            System.debug('Synced OwnerId for '
                + toSync.size() + ' leads');
        }
    }
}