public with sharing class LeadCaptureController {

    @AuraEnabled
    public static String createLead(
        String firstName,  String lastName,
        String company,    String email,
        String phone,      String leadSource,
        String productInterest
    ) {
        try {
            Lead l = new Lead(
                FirstName           = firstName,
                LastName            = lastName,
                Company             = company,
                Email               = email,
                Phone               = phone,
                LeadSource          = leadSource,
                Product_Interest__c = productInterest,
                Status              = 'Open - Not Contacted'
            );
            insert l;

            // ADDED: send auto-response immediately after insert
            if (email != null) {
                sendAutoResponse(l);
            }

            return l.Id;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Auto-response email ───────────────────────────────────────
    private static void sendAutoResponse(Lead l) {
        try {
            // Find the email template by developer name
            List<EmailTemplate> tmpls = [
                SELECT Id
                FROM   EmailTemplate
                WHERE  DeveloperName = 'Lead_Auto_Response'
                LIMIT  1
            ];

            // Guard — if template not found, skip silently
            if (tmpls.isEmpty()) {
                System.debug(
                    'Auto-response skipped: ' +
                    'Lead_Auto_Response template not found.'
                );
                return;
            }

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setTargetObjectId(l.Id);        // merge fields resolve against this Lead
            mail.setTemplateId(tmpls[0].Id);     // use the HTML template
            mail.setWhatId(l.Id);                // logs on Lead activity timeline
            mail.setSaveAsActivity(true);        // appears in Activity Timeline
            mail.setSenderDisplayName(
                'Creative Encode Sales Team'
            );

            Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ mail }
            );

        } catch (Exception e) {
            // Email failure must NOT block lead creation
            // Lead is already inserted — just log and move on
            System.debug(
                'Auto-response email failed: ' + e.getMessage()
            );
        }
    }

    
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getLeadSources() {
        List<Map<String,String>> opts = new List<Map<String,String>>();
        Schema.DescribeFieldResult dfr = Lead.LeadSource.getDescribe();
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
            if (e.isActive()) {
                opts.add(new Map<String,String>{
                    'label' => e.getLabel(),
                    'value' => e.getValue()
                });
            }
        }
        return opts;
    }
}