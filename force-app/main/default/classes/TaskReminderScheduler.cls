public class TaskReminderScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        sendOverdueReminders();
    }

    public static void sendOverdueReminders() {
        List<Task> overdueTasks = [
            SELECT Id, Subject, OwnerId,
                   WhatId, ActivityDate,
                   Owner.Email, Owner.Name,
                   What.Name
            FROM   Task
            WHERE  ActivityDate < TODAY
            AND    Status NOT IN (
                       'Completed', 'Deferred')
            AND    IsClosed = false
            AND    WhatId != null
            LIMIT  200
        ];
        if (overdueTasks.isEmpty()) return;

        // Group tasks by owner
        Map<Id, List<Task>> tasksByOwner =
            new Map<Id, List<Task>>();
        for (Task t : overdueTasks) {
            if (!tasksByOwner.containsKey(t.OwnerId))
                tasksByOwner.put(t.OwnerId,
                    new List<Task>());
            tasksByOwner.get(t.OwnerId).add(t);
        }

        // Send email digest per owner
        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();
        for (Id ownerId : tasksByOwner.keySet()) {
            List<Task> tasks = tasksByOwner.get(ownerId);
            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(ownerId);
            mail.setSubject('Action required: '
                + tasks.size() + ' overdue task'
                + (tasks.size() > 1 ? 's' : ''));
            mail.setHtmlBody(buildEmailBody(tasks));
            mail.setSaveAsActivity(false);
            emails.add(mail);
        }
        if (!emails.isEmpty())
            Messaging.sendEmail(emails);

        // ✅ FIXED: actually call sendBellNotifications
        //    was previously only a comment — now a real call
        sendBellNotifications(tasksByOwner);
    }

    // ✅ FIXED: moved outside sendOverdueReminders()
    //    was nested inside the method body — now a proper
    //    class-level method
    public static void sendBellNotifications(
        Map<Id, List<Task>> tasksByOwner) {

        List<CustomNotificationType> cnts = [
            SELECT Id FROM CustomNotificationType
            WHERE  DeveloperName = 'Overdue_Task_Alert'
            LIMIT  1
        ];
        if (cnts.isEmpty()) return;

        for (Id ownerId : tasksByOwner.keySet()) {
            List<Task> tasks = tasksByOwner.get(ownerId);
            try {
                Messaging.CustomNotification notif =
                    new Messaging.CustomNotification();
                notif.setNotificationTypeId(cnts[0].Id);
                notif.setTitle(
                    tasks.size() + ' overdue task'
                    + (tasks.size() > 1 ? 's' : '')
                );
                notif.setBody(
                    'Oldest: ' + tasks[0].Subject
                );
                notif.setTargetId(tasks[0].WhatId);
                notif.send(
                    new Set<String>{ (String) ownerId }
                );
            } catch (Exception e) {
                System.debug(
                    'Bell notif failed: '
                    + e.getMessage()
                );
            }
        }
    }

    private static String buildEmailBody(
        List<Task> tasks) {
        String rows = '';
        for (Task t : tasks) {
            Integer daysOverdue =
                t.ActivityDate != null
                ? t.ActivityDate.daysBetween(Date.today())
                : 0;
            rows += '<tr><td style="padding:8px 12px;'
                + 'border-bottom:1px solid #eee">'
                + t.Subject + '</td><td style="padding:'
                + '8px 12px;border-bottom:1px solid #eee">'
                + (t.What != null ? t.What.Name : '-')
                + '</td><td style="padding:8px 12px;'
                + 'border-bottom:1px solid #eee;color:#c23934;'
                + 'font-weight:500">'
                + daysOverdue + ' day'
                + (daysOverdue != 1 ? 's' : '')
                + ' overdue</td></tr>';
        }
        return '<html><body style="font-family:Arial,'
            + 'sans-serif;color:#1a1a1a;max-width:600px">'
            + '<div style="background:#185FA5;padding:20px'
            + ' 24px;border-radius:8px 8px 0 0"><h2 style='
            + '"color:#fff;margin:0;font-size:18px">'
            + 'Overdue Tasks — Action Required'
            + '</h2></div><div style="padding:20px;'
            + 'border:1px solid #e0e0e0"><p>You have <strong>'
            + tasks.size() + '</strong> overdue task'
            + (tasks.size() > 1 ? 's' : '')
            + '</p><table width="100%"><thead><tr>'
            + '<th style="text-align:left;padding:8px 12px;'
            + 'background:#f5f5f5">Task</th><th style="'
            + 'text-align:left;padding:8px 12px;background:'
            + '#f5f5f5">Opportunity</th><th style="'
            + 'text-align:left;padding:8px 12px;background:'
            + '#f5f5f5">Overdue by</th></tr></thead>'
            + '<tbody>' + rows
            + '</tbody></table></div></body></html>';
    }
}