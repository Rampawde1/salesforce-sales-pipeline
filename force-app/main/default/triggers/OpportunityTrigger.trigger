trigger OpportunityTrigger on Opportunity (before insert, before update, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        OpportunityHelper.setStageDate(Trigger.new, null);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        OpportunityHelper.setStageDate(Trigger.new, Trigger.oldMap);
        OpportunityHelper.validateCloseDate(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityHelper.postStageChatter(
            Trigger.new, Trigger.oldMap);
    }
}