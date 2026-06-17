trigger LeadTrigger on Lead (
    before insert, before update, after insert) {

    if (Trigger.isBefore && Trigger.isInsert) {
        LeadRouter.scoreLead(Trigger.new);
        LeadRouter.assignLeads(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        List<Lead> changed = new List<Lead>();
        for (Lead l : Trigger.new) {
            Lead old = Trigger.oldMap.get(l.Id);
            if (l.LeadSource        != old.LeadSource
             || l.Email             != old.Email
             || l.Phone             != old.Phone
             || l.NumberOfEmployees != old.NumberOfEmployees) {
                changed.add(l);
            }
        }
        if (!changed.isEmpty())
            LeadRouter.scoreLead(changed);
    }

    // ✅ NEW: after insert — sync OwnerId to
    //    match Assigned_SDR__c after Assignment
    //    Rule has potentially overwritten it
    if (Trigger.isAfter && Trigger.isInsert) {
        LeadRouter.syncOwnerAfterInsert(Trigger.new);
    }
}